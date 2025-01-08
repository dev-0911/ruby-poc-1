# frozen_string_literal: true

class GraphqlController < ApplicationController
  # taken from https://github.com/howtographql/graphql-ruby/blob/master/app/controllers/graphql_controller.rb
  include GraphqlHelper

  # If accessing from outside this domain, nullify the session
  # This allows for outside API access while preventing CSRF attacks,
  # but you'll have to authenticate your user separately
  # protect_from_forgery with: :null_session

  skip_before_action :verify_authenticity_token

  before_action :set_tracing_context

  QUERIES_WITHOUT_CONTEXT = [
    "createGoogleWorkspaceAccount",
    "createOffice365Account",
    "resetUserPassword",
    "globalSignInUser",
    "signInUser",
    "signOutUser",
    "signUpUser",
    "updateUserPassword",
    "getWorkosAuthorizationUrl",
    "sendMagicLinkEmail",
    "CreateTrustCenterRequest",
    "GetTrustCenterNDA",
    "GetTrustCenterVersion",
    "GetTrustCenterVersionMonitoringSection",
    "GetTrustCenterRequest",
    "CreateTrustCenterNdaClickwrapAgreement",
    "TrustCenterFaqSummarySearch",
    "faqQuery",
    "IntrospectionQuery"
  ].compact.freeze

  AUTH_ERRORS = {
    UNAUTHORIZED: "unauthorized",
    MSP_SESSION_EXPIRED: "msp_session_expired"
  }.with_indifferent_access.freeze

  def process_query(operation_params, index = 0)
    operation_name = operation_params[:operationName]
    query = operation_params[:query]
    variables = ensure_hash(operation_params[:variables])

    Datadog::Tracing.trace("graphql.operation", tags: {"graphql.operation_name": operation_name}) do |dd_span|
      Sentry.configure_scope do |sentry_scope|
        sentry_scope.set_tags(
          {
            company_id: current_company_user&.company_id,
            company_user_id: current_company_user&.id,
            operation_name: operation_name
          }
        )

        dd_span.set_tags({
          "secureframe.user_id": current_user&.id,
          "secureframe.company_user_id": current_company_user&.id,
          "secureframe.company_id": current_company_user&.company_id
        })

        variables = reparse_variables(variables, operation_name, index)

        context = {
          current_user: current_user,
          current_company_user: current_company_user,
          current_ability: Ability.new(current_user, current_company_user),
          ip_address: request.remote_ip
        }

        if (error_result = session_invalid?(operation_name))
          return [error_result, context]
        end

        Rails.logger.info("Current user: #{current_company_user&.email}")
        Rails.logger.info("Current company user: #{current_company_user&.id}")

        result = SecureframeSchema.execute(
          query,
          variables: variables,
          context: context,
          operation_name: operation_name
        )

        handle_auth_operations(result, operation_name, context)

        [{json: result}, context]
      end
    end
  end

  def execute
    if batching_enabled?
      execute_batched
    else
      execute_regular
    end
  rescue => e
    raise e unless Rails.application.config.log_gql_errors
    handle_error_in_development(e)
  ensure
    response.stream.close
  end

  def execute_batched
    batched_params = [params]
    batched_params = params.require(:_json) if multiple_queries? && !multipart_or_url_encoded?

    results = batched_params.each_with_index.map do |operation_params, index|
      operation_params = operation_params.transform_keys(&:to_sym)
      process_query(operation_params, index)[0]
    end

    return render(**results.first) unless multiple_queries?

    http_status = results.find { |result| result[:status] != 200 }&.dig(:status) || 200
    render(json: results.map { |result| result[:json] }, status: http_status)
  end

  def execute_regular
    result, context = process_query(params)

    # Regular (non-batched) GraphQL requests support using @defer directive to stream results
    if (deferred = context[:defer])
      # Required for Rack 2.2+, see https://github.com/rack/rack/issues/1619
      response.headers["Last-Modified"] = Time.now.httpdate

      deferred.stream_http_multipart(response, incremental: true)
    else
      render(**result)
    end
  end

  private def sign_in_user(user_id)
    return unless user_id

    user = User.find(user_id)
    if user
      set_auth_cookie(user)
    end
  end

  private def current_user
    return @current_user if @current_user

    header = request.headers["Authorization"]
    header_token = header&.partition("Bearer ")&.last

    # ALLOWS TO LOGIN WITH /login?authToken=someToken
    if header_token
      set_old_auth_cookie(header_token)
    end

    @current_user = get_user_from_auth_cookie
  end

  private def current_company_user
    return if current_user.blank?

    variables = ensure_hash(first_param[:variables])
    return if variables[:current_company_user_id].blank?
    # eager load the company with a join to use later
    @current_company_user ||= CompanyUser.eager_load(:company)
      .where(user: current_user)
      .find(variables[:current_company_user_id])
  end

  private def handle_error_in_development(e)
    Sentry.capture_exception(e)

    render(json: {error: {message: e.message, backtrace: e.backtrace}, data: {}}, status: 500)
  end

  private def set_sentry_context
    # NOTE: while email and names are available, it's preferred not to set that kind of PII
    Sentry.set_user(id: current_company_user&.user_id)
    Sentry.set_tags(
      company_id: current_company_user&.company_id,
      company_user_id: current_company_user&.id
    )
  end

  private def set_tracing_context
    Tracing.set_tags(
      company_id: current_company_user&.company_id,
      user_id: current_user&.id,
      company_user_id: current_company_user&.id,
      company_internal: current_company_user&.company&.internal
    )
  end

  private def append_info_to_payload(payload)
    # appends to datadog log hash by using
    # https://api.rubyonrails.org/classes/ActionController/Instrumentation.html#method-i-append_info_to_payload
    # to subscribe to the events broadcasted
    # https://github.com/rails/rails/blob/8015c2c2cf5c8718449677570f372ceb01318a32/actionpack/lib/action_controller/metal/instrumentation.rb#L66
    super
    return unless current_user
    return unless current_company_user
    payload[:company_id] = current_company_user.company_id
    payload[:user_id] = current_user.id
    payload[:company_user_id] = current_company_user.id
    payload[:company_internal] = current_company_user.company.internal
  end

  private def first_param
    body = ensure_hash(params)
    @first_param ||= multiple_queries? ? body[:_json].first : body
  end

  private def multipart_or_url_encoded?
    [:multipart_form, :url_encoded_form].include?(request.content_mime_type.symbol)
  end

  private def multiple_queries?
    params.key?(:_json)
  end

  private def batching_enabled?
    batching = FeatureFlag.instance.enabled_globally?(FeatureFlag::BATCH_GRAPHQL_REQUESTS)
    return false unless batching.is_a?(Hash)

    batching[:enabled]
  end

  # Re-parse the given request body and extract the variables to avoid null values being filtered out
  # from arrays in `params` due to deep munge.
  # Fix taken from this source: rmosolgo/graphql-ruby#1770 (linked from this issue: rmosolgo/graphql-ruby#2868)
  private def reparse_variables(variables, operation_name, index)
    if [:multipart_form, :url_encoded_form].include?(request.content_mime_type.symbol) ||
        ["signInUser", "signOutUser"].include?(operation_name)
      return variables
    end

    deep_munge_whitelist = [
      variables[:searchkick],
      variables.dig(:attributes, :searchkick),
      variables.dig(:input, :data, :searchkick_input),
      variables[:searchkickTableViewCount]
    ]

    json_body = ensure_hash(request.body.read)
    reparsed_variables = (json_body.is_a?(Array) ? json_body[index] : json_body)["variables"]

    if deep_munge_whitelist.any?
      variables = reparsed_variables
    elsif reparsed_variables != variables
      Rails.logger.error("Parsed params do not match reparsed json variables for operation #{operation_name}")
    end

    variables
  end

  private def session_invalid?(operation_name)
    if current_user.nil? && current_company_user.nil? && QUERIES_WITHOUT_CONTEXT.exclude?(operation_name)
      if !(Rails.env.cypress? && operation_name == "getUserSignedIn")
        sign_out_user

        return {
          json: {
            error: {message: "You are not signed in", errorId: AUTH_ERRORS[:UNAUTHORIZED]}
          },
          status: 401
        }
      end
    end

    if current_company_user
      is_external = current_company_user.employee_type == CompanyUser::EXTERNAL

      if is_external && current_company_user.access_session.nil?
        {
          json: {
            error: {message: "Your session expired", errorId: AUTH_ERRORS[:MSP_SESSION_EXPIRED]}
          },
          status: 401
        }
      end
    end
  end

  private def handle_auth_operations(result, operation_name, context)
    result_hash = result.to_h

    if operation_name == "signInUser"
      sign_in_user(result_hash.dig("data", "signInUser", "user", "id"))
    end

    if operation_name == "globalSignInUser"
      # if the mutation was successful it will set the current_user
      if context[:current_user].present?
        set_auth_cookie(context[:current_user])
      end
    end

    if operation_name == "refreshGlobalAuthToken"
      if current_user.present?
        set_global_auth_cookie(create_auth_payload(current_user))
      end
    end

    if operation_name == "signOutUser"
      sign_out_user
    end
  end
end

# Loading hooks to tweak features in sandbox mode.
ActiveSupport.run_load_hooks(:graphql_controller)
