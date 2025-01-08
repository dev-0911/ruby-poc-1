# frozen_string_literal: true

# @authorization [api_key] header Authorization
class Api::BaseController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :authenticate_api_key!
  before_action :set_datadog_span
  before_action :authorize_permission
  before_action :load_and_authorize_resource, only: [:show, :update, :destroy]
  before_action :load_and_authorize_resources, only: [:index]

  respond_to :json

  class BadFilterException < StandardError
  end

  class BadInputException < StandardError
  end

  class BadSortException < StandardError
  end

  # Rescue from various exceptions. These bubble up, so more specific should be at the bottom.
  rescue_from Exception, with: :render_server_error
  rescue_from BadFilterException, with: :render_bad_request_error
  rescue_from BadInputException, with: :render_bad_request_error
  rescue_from BadSortException, with: :render_bad_request_error
  rescue_from ArgumentError, with: :render_bad_request_error
  rescue_from ActiveRecord::RecordNotFound, with: :render_bad_request_error
  rescue_from ActiveRecord::AssociationNotFoundError, with: :render_bad_request_error
  rescue_from JSONAPI::Serializer::UnsupportedIncludeError, with: :render_bad_request_error
  rescue_from Date::Error, with: :render_bad_request_error

  # @response 403 Forbidden
  # @response 401 Unauthorized
  # @response 400 Bad Request
  #
  # @abstract
  def create
    outcome = run(
      interaction_create_klass,
      set_create_interaction_variables(valid_params: valid_create_params)
    )
    render_interaction_outcome(outcome)
  end

  # @response 404 Resource not found
  # @response 403 Forbidden
  # @response 401 Unauthorized
  # @response 400 Bad Request
  #
  # @abstract
  def destroy
    outcome = run(
      interaction_delete_klass,
      set_delete_interaction_variables
    )
    if outcome.valid? && outcome.result
      # Note: delete interactions are currently not standardized in what they return. For now, we'll return a
      # standardized success message
      render(json: {message: I18n.t("api.controllers.base.success", model: model_translation)})
    else
      render_interaction_errors(outcome)
    end
  end

  # @parameter page          [integer] Used for pagination of response data (default: 25 items per response). Specifies the offset of the next block of data to receive.
  # @parameter per_page      [integer] Used for pagination of response data (default: 25 items per response). Specifies the number of results for a given page.
  # @parameter relationships [boolean] Set to true to return the associated relationships data within the response. (default: false)
  # @parameter include       [boolean] Set to true along with relationships to return the entire relationship data in the `included` key within the response.
  # @parameter q             [string]  Search and filter the resources data using Lucene syntax.
  #
  # @response 403 Forbidden
  # @response 401 Unauthorized
  # @response 400 Bad Request
  #
  # @abstract
  def index
    render(json: serialized_data(@resources))
  end

  # @response 404 Resource not found
  # @response 403 Forbidden
  # @response 401 Unauthorized
  # @response 400 Bad Request
  #
  # @abstract
  def show
    render(json: serialized_data(@resource))
  end

  # @response 404 Resource not found
  # @response 403 Forbidden
  # @response 401 Unauthorized
  # @response 400 Bad Request
  #
  # @abstract
  def update
    outcome = run(
      interaction_update_klass,
      set_update_interaction_variables(valid_params: valid_update_params)
    )
    render_interaction_outcome(outcome)
  end

  # Render a 400 when a user has submitted an UnsupportedIncludeError or AssociationNotFoundError
  def render_bad_request_error(exception)
    render(json: {message: exception.message}, status: 400)
  end

  def render_forbidden
    render(json: {message: I18n.t("api.controllers.errors.forbidden")}, status: 403)
  end

  def render_not_found
    render(json: {message: I18n.t("api.controllers.errors.url_not_found")}, status: 404)
  end

  # resource_name is the user visible name of the resource (translated with I18n), e.g. "Company Test"
  def render_resource_not_found(resource_name)
    render(json: {message: I18n.t("api.models.errors.not_found", model: resource_name)}, status: 404)
  end

  # This is the top level response that we log and send to Sentry in the event of an uncaught 500 somewhere in our code.
  def render_server_error(e)
    Rails.logger.error("REST API Error: #{e}")
    Sentry.capture_exception(e)
    render(json: {message: I18n.t("api.controllers.errors.application_error")}, status: 500)
  end

  def render_unauthorized
    render(json: {message: I18n.t("api.controllers.errors.unauthorized")}, status: 401)
  end

  # Based on the action currently running, get the corresponding ability
  private def ability_by_action
    case action_name
    when "create"
      :create
    when "show", "index"
      :read
    when "update"
      :update
    when "destroy"
      :destroy
    end
  end

  # Before action to check the authorization header.
  # If the authorization header is blank, malformed, the ApiKey associated with it is revoked/not found
  # then they will get an unauthorized 401
  private def authenticate_api_key!
    if request.headers["Authorization"].blank?
      render_unauthorized
      return
    end
    token = request.headers["Authorization"].presence
    id, secret = token.split(" ")
    if id.blank? || secret.blank?
      render_unauthorized
      return
    end
    api_key = ApiKey.find_by(id: id, revoked_at: nil)&.authenticate_key(secret)
    if api_key.blank?
      render_unauthorized
      return
    end
    @api_key ||= api_key
    @api_key.update_column(:last_used_at, Time.now)
  end

  # Checks authorization of CompanyUser owner_id based on the owner's ability
  private def authorize_owner
    owner_id = params[:owner_id]
    return if owner_id.blank?
    translation = I18n.t("api.models.#{CompanyUser.to_s.underscore}")
    authorize_resource(CompanyUser, owner_id, :update, translation)
  end

  # Checks authorization for a controller based on the RBAC of a user
  private def authorize_permission
    permission = const_or_default(:PERMISSION_REQUIRED, false)
    return unless permission
    unless @api_key.owner.has_permission?(permission)
      render_forbidden
      nil
    end
  end

  # Checks authorization of the resource based on the owner's ability
  private def authorize_resource(resource_klass, resource_id, ability, translation)
    resource = resource_klass.find_by(id: resource_id)
    unless resource
      render_resource_not_found(translation)
      return
    end
    unless current_ability.can?(ability, resource)
      render_forbidden
      return
    end
    resource
  end

  # Get a constant defined in the current controller, or return default
  private def const_or_default(const, default)
    if current_controller_klass.const_defined?(const)
      current_controller_klass.const_get(const)
    else
      default
    end
  end

  # Get a constant define in the current controller, or return default as class
  private def const_or_default_klass(const, default_klass)
    const_or_default(const, default_klass).constantize
  end

  # Get the name of the controller in CamelCase as a string
  # e.g. "CompanyTests"
  private def controller_camel
    controller_name.camelcase
  end

  # Get the name of the resource we're querying against as a string
  # e.g. "CompanyTest"
  private def controller_resource
    const_or_default(:RESOURCE, controller_camel).singularize
  end

  # Get the name of the resource we're querying against as a class
  # e.g. CompanyTest
  private def controller_resource_klass
    controller_resource.constantize
  end

  private def api_filterable_data
    return @api_filterable_data if defined?(@api_filterable_data)

    if controller_resource_klass.const_defined?(:API_FILTERABLE_DATA)
      @api_filterable_data = controller_resource_klass.const_get(:API_FILTERABLE_DATA)
    end

    @api_filterable_data
  end

  # Create the ability for the owner of the API key. This is used for RBAC.
  private def current_ability
    Ability.new(@api_key.owner.user, @api_key.owner)
  end

  # Get the name current controller as a class
  # e.g. Api::CompanyTestsController
  private def current_controller_klass
    "#{controller_path.classify.pluralize}Controller".constantize
  end

  # Get the default context that we pass as params to all serializers if needed
  private def default_context
    {
      company: @api_key.company,
      company_id: @api_key.company_id,
      company_user_id: @api_key.owner_id
    }
  end

  private def default_rails_includes
    @default_includes ||= const_or_default(:DEFAULT_RAILS_INCLUDES, nil)
  end

  private def errors_response(object)
    {errors: serialize_interaction_errors(object)}
  end

  # Get the input type we're inputting against as a class
  # e.g. Types::Inputs::CompanyTestInput
  private def input_type_create_klass
    const_or_default_klass(:INPUT_TYPE_CREATE, "Types::Inputs::#{controller_camel.singularize}Input")
  end

  # Get the arguments from the input type as a list of underscore'd symbols
  private def input_type_create_klass_arguments
    input_type_create_klass.arguments.keys.map(&:underscore).map(&:to_sym)
  end

  # Get the input type we're inputting against as a class
  # e.g. Types::Inputs::CompanyTestInput
  private def input_type_update_klass
    const_or_default_klass(:INPUT_TYPE_UPDATE, "Types::Inputs::#{controller_camel.singularize}Input")
  end

  # Get the arguments from the input type as a list of underscore'd symbols
  private def input_type_update_klass_arguments
    input_type_update_klass.arguments.keys.map(&:underscore).map(&:to_sym)
  end

  # Get the create interaction as a class
  # e.g. Risks::Create
  private def interaction_create_klass
    const_or_default_klass(:INTERACTION_CREATE, "#{controller_camel}::Create")
  end

  # Get the delete interaction as a class
  # e.g. ControlV2s::Delete
  private def interaction_delete_klass
    const_or_default_klass(:INTERACTION_DELETE, "#{controller_camel}::Delete")
  end

  # Get the update interaction as a class
  # e.g. CompanyTests::Update
  private def interaction_update_klass
    const_or_default_klass(:INTERACTION_UPDATE, "#{controller_camel}::Update")
  end

  # Loads and checks authorization of the resource based on the owner's ability
  private def load_and_authorize_resource
    @resource ||= authorize_resource(controller_resource_klass, params[:id], ability_by_action, model_translation)
  end

  # Loads (and searches) authorized resources based on the owner's ability
  private def load_and_authorize_resources
    # Note: this is different than default params that we use in app/lib/searchkick_executor.rb, due to the fact that
    # we're now using LUCENE query_string syntax
    bool = {filter: parse_filters}
    parms = {
      body: {
        query: {bool: bool},
        sort: parse_sort,
        _source: false
      },
      body_options: {track_total_hits: true},
      page: page_or_default,
      per_page: per_page_or_default
    }
    bool[:must] = {query_string: {query: parse_q}} if permitted_params[:q].present?

    parms[:includes] = parse_includes_rails if permitted_params[:include].present?
    parms[:includes] = Array.wrap(parms[:includes]) + default_rails_includes if default_rails_includes

    @resources = controller_resource_klass.search(**parms).to_a
  end

  # Get the i18n translation of the model
  # e.g. "company_test"
  private def model_translation
    I18n.t("api.models.#{const_or_default(:MODEL_TRANSLATION, controller_resource.underscore)}")
  end

  # Return the page provided by the end user or default to page 1
  private def page_or_default
    permitted_params[:page].presence.to_i || 1
  end

  # For a given ability, create filter of terms for accessible resources based on company_id as well as any default
  # search terms provided by the resource's controller
  private def parse_filters
    filters = []
    default_query_params = const_or_default(:DEFAULT_QUERY_PARAMS, nil)
    filters = default_query_params.dup if default_query_params.present?
    if controller_resource_klass.column_names.include?("company_id")
      filters << {term: {company_id: @api_key.company_id}}
    else
      resource_ids = controller_resource_klass.accessible_by(current_ability).pluck(:id)
      filters << {terms: {id: resource_ids}}
    end
    filters
  end

  # Given some query param q in Lucene syntax, extract every key:value pair and ensure that the keys are filterable,
  #  and transform to filterable keys if needed.
  private def parse_q
    if api_filterable_data
      final_q = permitted_params[:q]
      groups = final_q.scan(Lucene::LUCENE_PATTERN)
      groups.each do |group|
        # Take each group and if has an `:` then split into a specific where_clause
        if group.include?(":")
          # Split into exactly two groups
          split_group = group.split(":", 2)
          # Ensure that the key is filterable, otherwise, throw an error
          key = split_group[0]
          # Remove first character if it's -
          key = key[1..] if key.chr == "-"
          value = api_filterable_data[key.to_sym]
          # Check to see if what was filtered against is filterable, if so, convert to valid filter field if needed
          if value.present?
            final_q.sub!(group, "#{value[:key]}:#{split_group[1]}") if value[:key].to_s != key
          else
            raise BadFilterException, I18n.t("api.controllers.errors.filter", resource: model_translation, key: key)
          end
        end
      end
      final_q
    else
      "*"
    end
  end

  # Serializer expects the following format:
  # includes=:risk,:risk.owner,:risk.owner.company,:risk.owner.user,:company_test.test_v2
  private def parse_includes(to_sym = true)
    sorted = permitted_params[:include].split(",").sort
    to_sym ? sorted.map(&:to_sym) : sorted
  end

  # Given the serializer format => Convert to expected Rails format for includes
  #   :owner                                  => .includes(:owner)
  #   :owner.company.customer_success_manager => .includes(owner: [company: :customer_success_manager])
  #   :owner.user                             => .includes(owner: :user)
  private def parse_includes_rails
    output = []
    parse_includes(false).each do |include_param|
      output << shift_and_set_hash(include_param.split("."))
    end
    output
  end

  # Given a parameter of sort, parse and make into format expected by Elasticsearch
  # Input format is from our specification: https://jsonapi.org/format/#fetching-sorting
  # Output format is what is needed for Elasticsearch: https://www.elastic.co/guide/en/elasticsearch/reference/current/sort-search-results.html
  #   ?sort=name    => { name : { order: :asc, missing: "_last", unmapped_type: "keyword" }}
  #   ?sort=-name   => { name : { order: :desc, missing: "_first", unmapped_type: "keyword" }}
  # Multiple inputs are supported: `?sort=-name,id,-rank`
  private def parse_sort
    default_sort = [{_score: {order: :desc}}, {_id: {order: :asc}}]
    return default_sort if permitted_params[:sort].blank?

    custom_sort = permitted_params[:sort].split(",").map do |sort|
      order = :asc
      missing = "_last"
      if sort.chr == "-"
        # remove the - from the front of the string
        sort = sort[1..]
        order = :desc
        missing = "_first"
      end

      controller_resource_klass.filterable.keys
      unless controller_resource_klass.filterable.key?(sort.to_sym)
        raise BadSortException, I18n.t("api.controllers.errors.sort", resource: controller_resource, sort: sort)
      end
      {sort.to_sym => {order: order, missing: missing, unmapped_type: unmapped_type_for_ordering(sort)}}
    end
    [*custom_sort, *default_sort]
  end

  # Return the per_page provided by the end user, with a maximum of `rest_api_per_page`
  # This can be overridden on a per controller basis using `DEFAULT_QUERY_PER_PAGE`
  private def per_page_or_default
    if permitted_params[:per_page].present?
      [permitted_params[:per_page].to_i, Rails.configuration.rest_api_per_page].min
    else
      const_or_default(:DEFAULT_QUERY_PER_PAGE, Rails.configuration.rest_api_per_page)
    end
  end

  # Params that are permitted for requesting additional data for the serializers
  private def permitted_params
    params.permit(:include, :page, :per_page, :q, :relationships, :sort).to_h
  end

  # Render errors from interaction outcome
  private def render_interaction_errors(outcome)
    render(json: {errors: outcome.errors.full_messages}, status: 400)
  end

  private def render_interaction_outcome(outcome)
    if outcome.valid? && outcome.result
      render_object(outcome.result)
    else
      render_interaction_errors(outcome)
    end
  end

  # Render the passed in object
  private def render_object(object)
    render(json: serialized_data(object))
  end

  # Run an interaction
  private def run(interaction, **variables)
    interaction.run(variables)
    # return errors_response(outcome) unless outcome.valid?
  end

  private def serialize_interaction_errors(object)
    object.errors.map do |attribute, message|
      path = attribute.to_s.camelize(:lower)
      {
        path: path,
        message: message
      }
    end
  end

  # Return the serialized data, loading additional data through params and include if requested
  private def serialized_data(obj, options = {params: default_context, include: {}})
    if permitted_params[:relationships].present?
      options[:params][:relationships] = true
      if permitted_params[:include].present?
        options[:include] = parse_includes
      end
    end
    serializer_klass.new(obj, options).serializable_hash.to_json
  end

  # Get the serializer as a class (e.g. Api::CompanyTestSerializer)
  private def serializer_klass
    const_or_default_klass(:SERIALIZER, "Api::#{controller_camel.singularize}Serializer")
  end

  # Until we can completely standardize interactions, each controller needs to set their own variables
  # for each interaction. Similar to what we currently do in mutations.
  # See an example in app/controllers/api/risks_controller.rb
  private def set_create_interaction_variables(valid_params:)
    raise NotImplementedError
  end

  # Make sure that set the relevant span information for user_id, company_user_id, and company_id similar to how we
  # set them in graphql_controller.rb
  private def set_datadog_span
    Datadog::Tracing.active_span&.set_tags({
      "secureframe.user_id": @api_key.owner.user_id,
      "secureframe.company_user_id": @api_key.owner_id,
      "secureframe.company_id": @api_key.company_id
    })
  end

  # For deletion, we have mostly (completely?) standardized our interactions to accept a param of :id
  # We default to using `id` only, but this can be overridden as necessary.
  private def set_delete_interaction_variables
    {id: params[:id]}
  end

  # Until we can completely standardize interactions, each controller needs to set their own variables
  # for each interaction. Similar to what we currently do in mutations.
  # See an example in app/controllers/api/company_tests_controller.rb
  private def set_update_interaction_variables(valid_params:)
    raise NotImplementedError
  end

  # Given an array, get the first element as a symbol, otherwise get as a hash with the remainder returned as the value
  private def shift_and_set_hash(arr)
    first = arr.shift.to_sym
    if arr.size == 0
      first
    else
      {first => shift_and_set_hash(arr)}
    end
  end

  # Given a specific sort key, for a given model class, return the expected type for elasticsearch
  # Lifted from app/lib/searchkick_executor.rb
  private def unmapped_type_for_ordering(sort)
    case controller_resource_klass.filterable[sort]
    when :string
      :keyword
    when :boolean
      :boolean
    when :datetime, :date
      :date
    when :integer
      :integer
    else
      # TODO: add more types
      :keyword
    end
  end

  # Parse the arguments provided from the create input type and convert to permitted params
  # e.g. Types::Inputs::ControlV2Input
  # argument :name, String, required: false
  # argument :description, String, required: false
  # argument :key, String, required: false
  # [:name, :description, :key]
  private def valid_create_params
    params.permit(input_type_create_klass_arguments)
  end

  # Parse the arguments provided from the update input type and convert to permitted params
  # e.g. Types::Inputs::CompanyTestInput with the following arguments:
  # argument :enabled, Boolean, required: false
  # argument :disabled_justification, String, required: false
  # argument :passed_with_upload_justification, String, required: false
  # argument :owner_id, String, required: false
  # argument :tolerance_window_seconds, Types::Enums::DurationOptionsEnum, required: false
  # argument :next_due_date, GraphQL::Types::ISO8601DateTime, required: false
  # argument :test_interval_seconds, Types::Enums::DurationOptionsEnum, required: false
  # argument :promote_at, GraphQL::Types::ISO8601DateTime, required: false
  # Will return:
  # => [:enabled, :disabled_justification, :passed_with_upload_justification, :owner_id, :tolerance_window_seconds,
  # :next_due_date, :test_interval_seconds, :promote_at]
  private def valid_update_params
    params.permit(input_type_update_klass_arguments)
  end

  # Return a copy of all the variables needed for the create interaction
  # e.g. from app/interactions/control_v2s/create.rb:
  # string :company_id, default: nil
  # string :framework_requirement_id, default: nil
  # string :description
  # string :domain, default: nil
  # string :key
  # string :name
  # Will return:
  # => {:company_id=>nil, :framework_requirement_id=>nil, :description=>nil, :domain=>nil, :key=>nil, :name=>nil}
  private def variables_for_create_interaction
    interaction_create_klass.new.inputs.dup
  end

  # Return a copy of all the variables needed for the update interaction
  # e.g. from app/interactions/control_v2s/update.rb:
  # string :id
  # hash :params, default: {}, strip: false
  # Will return:
  # => {:id=>nil, :params=>{} }
  private def variables_for_update_interaction
    interaction_update_klass.new.inputs.dup
  end
end
