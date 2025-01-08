# frozen_string_literal: true

require "sentry-ruby"

module Integrations
  class OauthController < ApplicationController
    include GlobalAuthHelper
    skip_before_action :verify_authenticity_token

    MISSING_ACCOUNT_ERROR = "Account not found"
    OAUTH_LOGIN_DISABLED = "OAuth login disabled"
    GENERIC_ERROR = "Something went wrong"
    INVALID_ACCOUNT_DETAILS = "Invalid account details"
    ACCOUNT_ALREADY_CONNECTED = "Account already connected"
    INVALID_ORGANIZATION_ERROR = "Error connecting to organization"
    MULTIPLE_ORGANIZATION_ERROR = "More than one organization selected"
    NOT_ADMIN_ERROR = "Not an admin"
    MISSING_SCOPES_ERROR = "User does not have all required OAuth scopes"
    MISSING_COMPANY_VENDOR = "Company Vendor not found"
    CROSS_REGION_ERROR = "Cross region request failed"
    USER_CANCELLED_ERROR = "User cancelled installation"

    class OAuthFlowError < StandardError
      attr_reader :context
      def initialize(message, context = nil)
        @context = context
        super(message)
      end
    end

    class NotServiceAdminError < OAuthFlowError; end

    class MissingScopesError < OAuthFlowError; end

    class OrganizationAlreadyConnectedError < OAuthFlowError; end

    class MissingUserError < OAuthFlowError; end

    class MissingCompanyUserError < OAuthFlowError; end

    class MissingCompanyError < OAuthFlowError; end

    class MissingVendorError < OAuthFlowError; end

    class InvalidCompanyVendorError < OAuthFlowError; end

    class InvalidCompanyUserVendorError < OAuthFlowError; end

    class UserCancelledError < OAuthFlowError; end

    rescue_from OAuthFlowError do |exception|
      capture_exception(exception)
      redirect_with_error(GENERIC_ERROR, exception.message)
    end

    rescue_from ::Integrations::Base::Errors::InvalidOrganizationError do |exception|
      redirect_with_error(INVALID_ORGANIZATION_ERROR, exception.message)
    end

    rescue_from ::Integrations::Base::Errors::MultipleOrganizationSelectedError do |exception|
      capture_exception(exception)
      redirect_with_error(MULTIPLE_ORGANIZATION_ERROR, exception.message)
    end

    rescue_from ::Integrations::Base::Errors::UnauthorizedError,
      ::Integrations::Base::Errors::ForbiddenError do |exception|
      capture_exception(exception)
      redirect_with_error(INVALID_ACCOUNT_DETAILS, exception.message)
    end

    rescue_from ::Integrations::Base::Errors::DuplicateAuthenticationError,
      OrganizationAlreadyConnectedError do |exception|
      capture_exception(exception)
      redirect_with_error(ACCOUNT_ALREADY_CONNECTED, exception.message)
    end

    rescue_from NotServiceAdminError do |exception|
      redirect_with_error(NOT_ADMIN_ERROR, exception.message)
    end

    rescue_from UserCancelledError do |exception|
      redirect_with_error(USER_CANCELLED_ERROR, exception.message)
    end

    rescue_from MissingScopesError do |exception|
      capture_exception(exception)
      redirect_with_error(MISSING_SCOPES_ERROR, exception.message)
    end

    rescue_from Signet::AuthorizationError do |exception|
      if params["error"] && params["error"] == "consent_required"
        redirect_to(redirect_url)
      else
        capture_exception(exception)
        redirect_with_error(GENERIC_ERROR, exception.message)
      end
    end

    def google_cloud_identity_callback
      redirect_to(Integrations::Google::CloudIdentity::OauthCallback.new(params).call)
    end

    def okta_callback
      # Deprecated style, do not copy:
      authenticator = Okta::Authenticator.new(account_id: account_id)
      authenticator.receive_authorization_code(params[:code])
      CompanyVendorConnection.connect!(account_id: account_id)

      ::OktaSyncJob.perform_async(account_id)
      redirect_to(redirect_url)
    end

    def github_callback
      if params[:setup_action] == "request"
        raise Github::InvalidInstallation, Github::Authenticator::INSUFFICIENT_ACCESS_ON_ORGANIZATION_ERROR
      end

      if (error_state = params[:error])
        error_description = params[:error_description]
        case error_state
        when "application_suspended"
          raise ::Integrations::Base::Errors::UnauthorizedError.new(message: "Application is suspended")
        when "access_denied"
          raise ::Integrations::Base::Errors::UnauthorizedError.new(message: "Access denied during Github installation")
        when "redirect_uri_mismatch"
          raise ::Integrations::Base::Errors::UnauthorizedError.new(message: "Redirect Url does not match with the registered callback url")
        else
          raise OAuthFlowError, "Error during installation: #{error_state} [#{error_description}]"
        end
      end

      # Deprecated style, do not copy:
      authenticator = Github::Authenticator.new(account_id: account_id)
      authenticator.handle_successful_installation(params[:code], params[:installation_id])
      begin
        CompanyVendorConnection.connect!(account_id: account_id)
      rescue ActiveRecord::RecordNotFound
        error_log = "Company Vendor not found by account_id: #{account_id}"
        redirect_with_error(MISSING_COMPANY_VENDOR, error_log)
        return
      end

      connection = CompanyVendorConnection.find_by(account_id: account_id)
      connection.update(connection_settings: {testing_start_date: Time.zone.today.to_time.beginning_of_day})

      ::GithubSyncJob.perform_async(account_id)
      redirect_to(redirect_url)
    rescue Github::InvalidInstallation => exception
      redirect_with_error(
        exception.message,
        "Error installing github app for account_id: #{account_id} with params: #{params}"
      )
    end

    def gitlab_callback
      redirect_to(Integrations::Gitlab::OauthCallback.new(params).call)
    end

    def bitbucket_callback
      redirect_to(Integrations::Bitbucket::OauthCallback.new(params).call)
    end

    def jira_callback
      redirect_to(Integrations::Jira::OauthCallback.new(params).call)
    end

    def trello_callback
      redirect_to(Integrations::Trello::OauthCallback.new(params).call)
    end

    def heroku_callback
      redirect_to(Integrations::Heroku::OauthCallback.new(params).call)
    end

    def slack_callback
      redirect_to(Integrations::Slack::OauthCallback.new(params).call)
    end

    def gusto_callback
      redirect_to(Integrations::Gusto::OauthCallback.new(params).call)
    end

    def checkr_callback
      redirect_to(Integrations::Checkr::OauthCallback.new(params).call)
    end

    def azure_active_directory_callback
      redirect_to(Integrations::AzureActiveDirectory::OauthCallback.new(params).call)
    end

    def asana_callback
      redirect_to(Integrations::Asana::OauthCallback.new(params).call)
    end

    def linear_callback
      redirect_to(Integrations::Linear::OauthCallback.new(params).call)
    end

    def bamboo_callback
      redirect_to(Integrations::Bamboo::OauthCallback.new(params).call)
    end

    def service_now_callback
      redirect_to(Integrations::ServiceNow::OauthCallback.new(params).call)
    end

    def clickup_callback
      redirect_to(Integrations::Clickup::OauthCallback.new(params).call)
    end

    def zoom_callback
      redirect_to(Integrations::Zoom::OauthCallback.new(params).call)
    end

    def ninja_one_callback
      redirect_to(Integrations::NinjaOne::OauthCallback.new(params).call)
    end

    def deel_callback
      redirect_to(Integrations::Deel::OauthCallback.new(params).call)
    end

    def rippling_callback
      # Most of our integrations rely on state to pass in an account_id, which we can then use to match up to a
      # company_vendor. However, Rippling requires us to support initiation from the app shop, which means we can't
      # pass anything into the state variable on oauth flow initiation. To handle this we set a cookie with the
      # current company user's ID on the FE, and read that cookie here. This allows us to match up to a company
      company_user_id = request.cookies["current_company_user_id"]
      redirect_to(Integrations::Rippling::OauthCallback.new(params.merge({company_user_id: company_user_id})).call)
    end

    def google_callback
      include_user_groups = JsonWebToken.decode(params[:state])[:include_user_groups]
      persistor = Integrations::Google::GoogleWorkspace::Persistor.new(account_id: account_id)
      authenticator = Integrations::Google::GoogleWorkspace::Authenticator.new(persistor)
      auth_hash = authenticator.build_auth_info(code: params[:code])

      client = Integrations::Google::GoogleWorkspace::Client.new(
        Integrations::Base::PassThroughAuthenticator.new(auth_hash),
        persistor
      )

      if intent == Base::Deprecated::Authenticator::INTENT_CONNECT
        google_workspace_user = client.owner_user

        begin
          persistor.save_auth_info!(
            auth_hash,
            authenticator.authentication_type,
            {customer_id: google_workspace_user&.customer_id}
          )

          connection = CompanyVendorConnection.find_by(account_id: account_id)

          connection.update(connection_settings: {
            include_user_groups: include_user_groups
          })
        rescue ::Integrations::Base::Errors::DuplicateAuthenticationError
          raise OrganizationAlreadyConnectedError, "Google Workspace organization is already connected"
        end

        unless authenticator.all_google_scopes_present?
          raise MissingScopesError,
            "Google Workspace Connection - user does not have all required scopes"
        end

        connect_and_sync_account

        redirect_to(redirect_url)
        return
      end

      if intent == Base::Deprecated::Authenticator::INTENT_LOGIN
        if FeatureFlag.instance.enabled_globally?(FeatureFlag::GLOBAL_AUTH_SSO_ENABLED)
          primary_email = client.owner_primary_email.downcase
          third_party_id = client.owner_google_workspace_id
          google_workspace_user = client.user(primary_email)
          all_scopes_present = authenticator.all_google_scopes_present?

          home_region = PeerRegion.get_user_home_region(primary_email)

          if home_region && home_region.region != Rails.configuration.current_region_code
            return cross_region_login_google(
              home_region: home_region,
              primary_email: primary_email,
              third_party_id: third_party_id,
              auth_hash: auth_hash,
              google_workspace_customer_id: google_workspace_user&.customer_id,
              all_scopes_present: all_scopes_present
            )
          else
            return same_region_login_google(
              primary_email: primary_email,
              third_party_id: third_party_id,
              auth_hash: auth_hash,
              google_workspace_customer_id: google_workspace_user&.customer_id,
              all_scopes_present: all_scopes_present
            )
          end

        else

          third_party_id = client.owner_google_workspace_id
          company_user_vendors = CompanyUserVendor.kept.joins(:vendor).where(
            vendors: {slug: "google_workspace"},
            third_party_id: third_party_id
          )

          return handle_login_with_existing_vendor_connection(company_user_vendors) if company_user_vendors.present?

          primary_email = client.owner_primary_email.downcase
          user = User.find_by(email: primary_email)
          if user.nil?
            raise MissingUserError.new(
              "Google Workspace Login - could not find user by email",
              {email: primary_email}
            )
          end

          company_user = user.company_users.first
          if company_user.nil?
            raise MissingUserError.new("Google Workspace Login - could not find company_user by id", {id: user.id})
          end

          return handle_auditor_login(company_user) if company_user.auditor?

          admin_company_user = user.company_users.super_admin.first || user.company_users.admin.first
          if admin_company_user.blank?
            raise MissingCompanyUserError,
              "Google Workspace Login - could not find admin company_user, user_id: #{user.id}"
          end

          google_workspace_user = client.user(primary_email)

          unless authenticator.all_google_scopes_present?
            raise MissingScopesError,
              "Google Workspace Login - user does not have all required scopes: #{primary_email}"
          end

          return connect_google_workspace_and_login_user(
            company_user,
            auth_hash,
            third_party_id,
            google_workspace_user&.customer_id
          )
        end
      end

      redirect_to(redirect_url)
    end

    def office_365_callback
      if (error_state = params[:error])
        error_subcode = params[:error_subcode]
        if error_state == "access_denied"
          case error_subcode
          when "cancel"
            raise UserCancelledError, "User cancelled Office365 installation"
          end

          raise ::Integrations::Base::Errors::UnauthorizedError, "Access denied during Office365 installation"
        end

        raise OAuthFlowError, "Error during installation: #{error_state} [#{error_subcode}]"
      end

      include_guest_accounts, include_unlicensed_accounts, include_user_groups = JsonWebToken.decode(params[:state]).values_at(
        :include_guest_accounts,
        :include_unlicensed_accounts,
        :include_user_groups
      )
      authenticator = Microsoft::Office365::Authenticator.initialize_with_defaults(account_id: account_id)
      persistor = Microsoft::Office365::Persistor.new(account_id: account_id)
      auth_hash = authenticator.build_auth_info(code: params[:code])

      client = Integrations::Microsoft::Office365::Client.new(
        Integrations::Base::PassThroughAuthenticator.new(auth_hash),
        persistor
      )

      if intent == Base::Deprecated::Authenticator::INTENT_CONNECT
        raise NotServiceAdminError, "Connected Office365 account must be an admin" unless client.owner_user_is_admin?

        begin
          metadata = {
            organization_id: client.organization_id
          }
          persistor.save_auth_info!(auth_hash, authenticator.authentication_type, metadata)

          connection = CompanyVendorConnection.find_by(account_id: account_id)
          connection.update(connection_settings: {
            include_guest_accounts: include_guest_accounts,
            include_unlicensed_accounts: include_unlicensed_accounts,
            include_user_groups: include_user_groups
          })
        rescue ::Integrations::Base::Errors::DuplicateAuthenticationError
          raise OrganizationAlreadyConnectedError, "Office365 organization is already connected"
        end

        connect_and_sync_account

        redirect_to(redirect_url)
        return
      end

      if intent == Base::Deprecated::Authenticator::INTENT_LOGIN
        owner_user = client.owner_user
        third_party_id = owner_user["id"]
        primary_email = owner_user["mail"]

        if FeatureFlag.instance.enabled_globally?(FeatureFlag::GLOBAL_AUTH_SSO_ENABLED)
          home_region = PeerRegion.get_user_home_region(primary_email)

          if home_region && home_region.region != Rails.configuration.current_region_code
            return cross_region_login_office_365(
              home_region: home_region,
              primary_email: primary_email,
              third_party_id: third_party_id
            )
          else
            return same_region_login_office_365(
              primary_email: primary_email,
              third_party_id: third_party_id
            )
          end
        else
          company_user_vendors = CompanyUserVendor.kept.joins(:vendor).where(
            vendors: {slug: "office_365"},
            third_party_id: third_party_id
          )

          return handle_login_with_existing_vendor_connection(company_user_vendors) if company_user_vendors.present?

          raise MissingUserError,
            "Office365 Login - could not find company_user_vendor with third_party_id: #{third_party_id}"
        end
      end

      redirect_to(redirect_url)
    end

    def intune_callback
      account_id, redirect_url = JsonWebToken.decode(params[:state]).values_at(:account_id, :redirect_url)
      authenticator = Microsoft::Intune::Authenticator.initialize_with_defaults(account_id: account_id)
      persistor = Microsoft::Intune::Persistor.new(account_id: account_id)
      auth_hash = authenticator.build_auth_info(code: params[:code])
      client = Integrations::Microsoft::Intune::Client.new(
        Integrations::Base::PassThroughAuthenticator.new(auth_hash),
        persistor
      )

      raise NotServiceAdminError, "Connected Intune account must be an admin" unless client.owner_user_is_admin?

      begin
        metadata = {organization_id: client.organization_id}
        persistor.save_auth_info!(auth_hash, authenticator.authentication_type, metadata)
      rescue ::Integrations::Base::Errors::DuplicateAuthenticationError
        raise OrganizationAlreadyConnectedError, "Intune organization is already connected"
      end

      connect_and_sync_account

      redirect_to(redirect_url)
    end

    def azure_devops_callback
      account_id, redirect_url = JsonWebToken.decode(params[:state]).values_at(:account_id, :redirect_url)
      authenticator = Microsoft::AzureDevops::Authenticator.initialize_with_defaults(account_id: account_id)
      persistor = Microsoft::AzureDevops::Persistor.new(account_id: account_id)
      auth_hash = authenticator.build_auth_info(code: params[:code])
      client = Integrations::Microsoft::AzureDevops::Client.new(
        Integrations::Base::PassThroughAuthenticator.new(auth_hash),
        persistor
      )

      begin
        organization_id = client.organization["accountId"]
        persistor.save_auth_info!(
          auth_hash,
          authenticator.authentication_type,
          authenticator.metadata.merge(organization_id: organization_id)
        )
      rescue ::Integrations::Base::Errors::DuplicateAuthenticationError
        raise OrganizationAlreadyConnectedError, "Azure DevOps organization is already connected"
      end

      connect_and_sync_account

      redirect_to(redirect_url)
    end

    private

    # Here, we have an admin user trying to log in with Google Workspace, who hasn't yet
    # set up their Google Workspace integration.
    # We'll set up the Google Workspace integration for them here, and log them in
    def connect_google_workspace_and_login_user(company_user, auth_hash, third_party_id, google_workspace_customer_id)
      company_user_vendor = create_company_user_vendor!("google_workspace", company_user, third_party_id)
      company_vendor_connection = company_user_vendor.company_vendor_connection

      persistor = Google::GoogleWorkspace::Persistor.new(account_id: company_vendor_connection.account_id)

      # TODO: refactor this code to make it less hacky
      persistor.save_auth_info!(auth_hash, :oauth, {customer_id: google_workspace_customer_id})

      company_vendor_connection.connect!
      ::SyncConnectionJob.perform_async(company_vendor_connection.account_id, SyncJobRun::ORIGIN_DEFAULT)

      handle_login_with_existing_vendor_connection([company_user_vendor])
    end

    def create_company_user_vendor!(slug, company_user, third_party_id)
      vendor = Vendor.find_by(slug: slug)
      if company_user.company.blank?
        raise MissingCompanyError, "Could not find company for company_user #{company_user.id}"
      end
      raise MissingVendorError, "Could not find vendor with slug '#{slug}'" if vendor.blank?

      result = CompanyVendorConnections::Create.run(
        params: {
          company_id: company_user.company.id,
          owner_id: company_user.id,
          vendor_id: vendor.id
        }
      )
      raise InvalidCompanyVendorError.new("Could not create CompanyVendor", result.errors) unless result.valid?

      connection = result.result

      company_user_vendor = CompanyUserVendor.create(
        company_id: company_user.company.id,
        company_user: company_user,
        account_id: connection.account_id,
        third_party_id: third_party_id
      )
      unless company_user_vendor.persisted?
        raise InvalidCompanyUserVendorError.new("Could not create CompanyUserVendor", result.errors.full_messages)
      end

      company_user_vendor
    end

    def handle_auditor_login(company_user)
      user = company_user.user

      return redirect_with_error(MISSING_ACCOUNT_ERROR) if user.blank?

      if !company_user.sign_in_type_allowed?(User::SIGN_IN_TYPE_OAUTH)
        return redirect_with_error(OAUTH_LOGIN_DISABLED)
      end

      user.update_last_sign_in_at_and_count!(User::SIGN_IN_TYPE_OAUTH)

      set_auth_cookie(user)
      redirect_to(build_redirect_url(redirect_url))
    end

    def handle_login_with_existing_vendor_connection(company_user_vendors)
      company_users = []
      company_user_vendors.each do |company_user_vendor|
        company_users << company_user_vendor&.company_user
      end
      company_users.uniq.compact!

      company_users = company_users.select do |company_user|
        company_user.can_sign_in?
      end

      return redirect_with_error(MISSING_ACCOUNT_ERROR) if company_users.blank?

      sign_in_type_allowed = company_users.all? do |company_user|
        company_user.sign_in_type_allowed?(User::SIGN_IN_TYPE_OAUTH)
      end

      return redirect_with_error(OAUTH_LOGIN_DISABLED) unless sign_in_type_allowed

      # Increment the total sign-in count
      user = company_users.first.user
      user.update_last_sign_in_at_and_count!(User::SIGN_IN_TYPE_OAUTH)

      set_auth_cookie(user)
      redirect_to(build_redirect_url(redirect_url))
    end

    def redirect_with_error(error, error_log = "")
      Rails.logger.info(error_log) if error_log.present?
      redirect_to(build_redirect_url(redirect_url, {error: error}))
    end

    def build_state_params
      @account_id, @redirect_url, @intent = JsonWebToken.decode(params[:state]).values_at(
        :account_id,
        :redirect_url,
        :intent
      )
      {
        account_id: @account_id,
        redirect_url: @redirect_url,
        intent: @intent
      }
    rescue JWT::VerificationError, JWT::DecodeError
      {}
    end

    def account_id
      @account_id ||= build_state_params[:account_id]
    end

    def redirect_url
      @redirect_url ||= build_state_params[:redirect_url] || request.base_url + "/integrations/connected"
    end

    def intent
      @intent ||= build_state_params[:intent]
    end

    def build_redirect_url(url, query_params = {})
      address = Addressable::URI.parse(url)
      address.query_values = (address.query_values || {}).merge(query_params)
      address.to_s
    end

    def capture_exception(exception)
      if exception.respond_to?(:context) && exception.context.present?
        ::Sentry.set_extras(exception.context)
      end
      ::Sentry.capture_exception(exception)
    end

    def connect_and_sync_account
      # TODO: De-couple integration layer from main app
      connection = CompanyVendorConnection.find_by(account_id: account_id)
      connection.connect!

      connection.sync_async(SyncJobRun::ORIGIN_DEFAULT)
    end

    private

    def cross_region_login_google(
      home_region:,
      primary_email:,
      third_party_id:,
      auth_hash:,
      google_workspace_customer_id:,
      all_scopes_present:
    )
      response = SendCrossRegionRequest.new(home_region.hostname, "/inside/google_oauth_sign_in", "POST", {
        primary_email: primary_email,
        third_party_id: third_party_id,
        auth_hash: auth_hash,
        google_workspace_customer_id: google_workspace_customer_id,
        all_scopes_present: all_scopes_present
      }).call

      if response.success?
        data = JSON.parse(response.body)

        return redirect_with_error(data["errors"][0]) if data["errors"].present?

        set_auth_cookie(ForeignUser.new(data["user"]))
        redirect_to(build_redirect_url(redirect_url))
      else
        redirect_with_error(CROSS_REGION_ERROR, response.body)
      end
    end

    def same_region_login_google(
      primary_email:,
      third_party_id:,
      auth_hash:,
      google_workspace_customer_id:,
      all_scopes_present:
    )
      outcome = ::Integrations::Google::GoogleWorkspace::PerformGoogleLogin.run(
        primary_email: primary_email,
        third_party_id: third_party_id,
        auth_hash: auth_hash,
        google_workspace_customer_id: google_workspace_customer_id,
        all_scopes_present: all_scopes_present
      )

      if outcome.valid?
        set_auth_cookie(outcome.result)
        redirect_to(build_redirect_url(redirect_url))
      else
        error_key = outcome.errors.attribute_names.first
        error_message = outcome.errors.messages_for(error_key).first
        report_login_errors(error_key, error_message, primary_email)
        redirect_with_error(error_message, "#{error_message} for #{primary_email}")
      end
    end

    def cross_region_login_office_365(
      home_region:,
      primary_email:,
      third_party_id:
    )
      response = SendCrossRegionRequest.new(home_region.hostname, "/inside/office_365_oauth_sign_in", "POST", {
        primary_email: primary_email,
        third_party_id: third_party_id
      }).call

      if response.success?
        data = JSON.parse(response.body)

        return redirect_with_error(data["errors"][0]) if data["errors"].present?

        set_auth_cookie(ForeignUser.new(data["user"]))
        redirect_to(build_redirect_url(redirect_url))
      else
        redirect_with_error(CROSS_REGION_ERROR, response.body)
      end
    end

    def same_region_login_office_365(
      primary_email:,
      third_party_id:
    )
      outcome = ::Integrations::Microsoft::Office365::PerformLogin.run(
        primary_email: primary_email,
        third_party_id: third_party_id
      )

      if outcome.valid?
        set_auth_cookie(outcome.result)
        redirect_to(build_redirect_url(redirect_url))
      else
        error_key, error_message = outcome.errors.messages.first
        report_login_errors(error_key, error_message, primary_email)
        redirect_with_error(error_message, "#{error_message} for #{primary_email}")
      end
    end

    def report_login_errors(error_key, error_message, primary_email)
      case error_key
      when :user
        raise MissingUserError, "#{error_message} for #{primary_email}"
      when :company_user
        raise MissingCompanyUserError, "#{error_message} for #{primary_email}"
      when :invalid_company_vendor_error
        raise InvalidCompanyVendorError, "#{error_message} for #{primary_email}"
      when :missing_company
        raise MissingCompanyError, "#{error_message} for #{primary_email}"
      end
    end
  end
end
