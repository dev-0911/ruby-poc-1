# frozen_string_literal: true

# @resource User Account
#
# This document describes the API for reading User Accounts.
#
# @tag_group Endpoints
# @authorize_with header_authorization
#
class Api::CompanyUserVendorsController < Api::BaseController
  before_action :load_and_authorize_resource, only: [:link, :show]
  before_action :authorize_company_user, only: [:link]

  DEFAULT_QUERY_PARAMS = [
    {term: {archived: false}},
    {term: {discarded: false}}
  ].freeze

  DEFAULT_RAILS_INCLUDES = [:company_user, {company_vendor: :vendor}]

  PERMISSION_REQUIRED = Permission::VENDOR_ACCESS

  ##
  # Returns a list of User Accounts.
  #
  # @path [GET] /user_accounts
  # @summary List User Accounts
  #
  # @parameter page          [integer] Used for pagination of response data (default: page 1). Specifies the offset of the next block of data to receive.
  # @parameter per_page      [integer] Used for pagination of response data (default: 1000 items per response). Specifies the number of results for a given page.
  # @parameter relationships [boolean] Set to true to return the associated relationships data within the response. (default: false)
  # @parameter include       [boolean] Set to true along with relationships to return the entire relationship data in the `included` key within the response.
  # @parameter q             [string]  Search and filter the User Account data using Lucene syntax.
  #
  # @response_type [array<UserAccount>]
  #
  # @response 403 Forbidden
  # @response 401 Unauthorized
  # @response 400 Bad Request
  #
  def index
    super
  end

  ##
  # Returns a single User Account by ID
  #
  # @path [GET] /user_accounts/{id}
  # @summary Get a User Account
  #
  # @response_type [UserAccount]
  #
  # @response 404 Resource not found
  # @response 403 Forbidden
  # @response 401 Unauthorized
  # @response 400 Bad Request
  #
  def show
    super
  end

  ##
  # Links a User to a User Account.
  #
  # @path [PUT] /user_accounts/{id}/link
  # @summary Link a User Account
  #
  # @parameter user_id [uuid] The ID of the user to link to the User Account. If user_id is not provided or is an empty string, the User Account will be unlinked.
  #
  # @response_type [UserAccount]
  #
  # @response 404 Resource not found
  # @response 403 Forbidden
  # @response 401 Unauthorized
  # @response 400 Bad Request
  #
  def link
    company_user_vendor_id = params[:id]
    company_user_id = params[:user_id]

    outcome = if company_user_id.present?
      run(
        CompanyUserVendors::Link,
        company_user_vendor_id: company_user_vendor_id,
        company_user_id: company_user_id
      )
    else
      run(
        CompanyUserVendors::Unlink,
        company_user_vendor_id: company_user_vendor_id
      )
    end

    render_interaction_outcome(outcome)
  end

  private def authorize_company_user
    company_user_id = params[:user_id]
    return if company_user_id.blank?
    translation = I18n.t("api.models.#{CompanyUser.to_s.underscore}")
    authorize_resource(CompanyUser, company_user_id, :update, translation)
  end
end
