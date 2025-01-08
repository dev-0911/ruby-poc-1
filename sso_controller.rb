# frozen_string_literal: true

class SsoController < ApplicationController
  include GlobalAuthHelper
  skip_before_action :verify_authenticity_token

  MISSING_COMPANY_ERROR = "Company not found"
  WORKOS_API_CALL_FAILED = "WorkOS API error response"
  ACCESS_NOT_ENABLED = "Access not enabled"
  SSO_LOGIN_DISABLED = "SSO login disabled"
  MAGIC_LINK_LOGIN_DISABLED = "Magic link login disabled"
  MAGIC_LINK_MISSING = "Magic link missing"
  MISSING_USER_ERROR = "User not found"
  MISSING_AUTHORIZATION_CODE = "Missing authorization code"

  def callback
    if params[:magic_link].present?
      magic_link = JsonWebToken.decode(params[:magic_link])["magic_link"]
      return redirect_to(magic_link) if magic_link.present?
      return redirect_with_error(MAGIC_LINK_MISSING, "Magic link missing")
    end

    if params[:code].blank?
      # This could also happen when coming from an expired magic link.
      error = MISSING_AUTHORIZATION_CODE
      error = params[:error_description] if params[:error].present?
      return redirect_with_error(
        MISSING_AUTHORIZATION_CODE,
        "WorkOS callback error - #{error}."
      )
    end

    begin
      profile_and_token = Api::Workos::Client.new.get_profile_and_token(params[:code])
    rescue WorkOS::APIError => error
      return redirect_with_error(
        WORKOS_API_CALL_FAILED,
        "SSO Login - WorkOS get_profile_and_token call failed: #{error.message}"
      )
    end

    profile = profile_and_token.profile
    sign_in_type = if profile.connection_type == Api::Workos::Client::MAGICLINK_SESSION_TYPE
      User::SIGN_IN_TYPE_MAGIC_LINK
    else
      User::SIGN_IN_TYPE_SSO
    end

    company = Company.find_by_slug(slug) if slug.present?
    if sign_in_type == User::SIGN_IN_TYPE_SSO && !idp_initiated_signin && company.blank?
      return redirect_with_error(
        MISSING_COMPANY_ERROR,
        "SSO Login - could not find company by slug: #{slug}"
      )
    end

    user = User.find_by("LOWER(email) = LOWER(?)", profile.email)
    company_user = nil

    if user.nil?
      return redirect_with_error(
        MISSING_USER_ERROR,
        "SSO Login - could not find user by email: #{profile.email}"
      )
    else
      company_users = user.company_users.where(invited: true)
      company_users = company_users.with_company_id(company.id) if company.present?
      company_users = company_users.select { |cu| cu.can_sign_in? }
      if company_users.blank?
        return redirect_with_error(
          ACCESS_NOT_ENABLED,
          "CompanyUser with sign-in privilege not found"
        )
      end

      company_user = company_users.find { |cu| cu.sign_in_type_allowed?(sign_in_type) }
      if company_user.blank?
        error = (sign_in_type == User::SIGN_IN_TYPE_MAGIC_LINK) ? MAGIC_LINK_LOGIN_DISABLED : SSO_LOGIN_DISABLED
        return redirect_with_error(error, "#{sign_in_type} sign-in not allowed")
      end
    end

    handle_login_with_existing_user(company_user, user, sign_in_type)
  end

  private

  def handle_login_with_existing_user(company_user, user, sign_in_type)
    # Increment the total sign-in count
    user.update_last_sign_in_at_and_count!(sign_in_type)

    set_auth_cookie(user)

    redirect_to landing_page_url
  end

  def build_redirect_url(url, query_params = {})
    address = Addressable::URI.parse(url)
    address.query_values = (address.query_values || {}).merge(query_params)
    address.to_s
  end

  def redirect_with_error(error, error_log = "")
    Rails.logger.info(error_log) if error_log.present?
    redirect_to(build_redirect_url(root_path, {error: error}))
  end

  def build_state_params
    base_url = "https://#{Rails.application.config.application_host}"
    base_url = "http://#{Rails.application.config.application_host}:3000" if Rails.env.development?
    base_url = "http://#{Rails.application.config.application_host}:3001" if Rails.env.dev_other_region?
    if params[:state].blank?
      {
        idp_initiated_signin: true,
        slug: nil,
        landing_page_url: base_url
      }
    else
      slug, landing_page_url = JsonWebToken.decode(params[:state]).values_at(
        :slug,
        :landing_page_url
      )
      {
        idp_initiated_signin: false,
        slug: slug,
        landing_page_url: "#{base_url}#{landing_page_url}"
      }
    end
  end

  def idp_initiated_signin
    @idp_initiated_signin ||= build_state_params[:idp_initiated_signin]
  end

  def slug
    @slug ||= build_state_params[:slug]
  end

  def landing_page_url
    @landing_page_url ||= build_state_params[:landing_page_url]
  end
end
