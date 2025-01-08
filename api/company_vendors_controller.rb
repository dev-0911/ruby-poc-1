# frozen_string_literal: true

# @resource Vendor
#
# This document describes the API for reading and archiving Vendors.
#
# @tag_group Endpoints
# @authorize_with header_authorization
#
class Api::CompanyVendorsController < Api::BaseController
  before_action :load_and_authorize_resource, only: [:archive, :show]

  DEFAULT_QUERY_PARAMS = [
    {term: {archived: false}},
    {terms: {
      status: [CompanyVendor::ADDED, CompanyVendor::CONNECTED, CompanyVendor::PENDING, CompanyVendor::DISABLED]
    }}
  ].freeze

  PERMISSION_REQUIRED = Permission::VENDORS
  DEFAULT_RAILS_INCLUDES = [:vendor]

  ##
  # Returns a list of Vendors.
  #
  # @path [GET] /vendors
  # @summary List Vendors
  #
  # @parameter page          [integer] Used for pagination of response data (default: page 1). Specifies the offset of the next block of data to receive.
  # @parameter per_page      [integer] Used for pagination of response data (default: 1000 items per response). Specifies the number of results for a given page.
  # @parameter relationships [boolean] Set to true to return the associated relationships data within the response. (default: false)
  # @parameter include       [boolean] Set to true along with relationships to return the entire relationship data in the `included` key within the response.
  # @parameter q             [string]  Search and filter the Vendor data using Lucene syntax.
  #
  # @response_type [array<Vendor>]
  #
  # @response 403 Forbidden
  # @response 401 Unauthorized
  # @response 400 Bad Request
  #
  def index
    super
  end

  ##
  # Returns a single Vendor by ID
  #
  # @path [GET] /vendors/{id}
  # @summary Get a Vendor
  #
  # @response_type [Vendor]
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
  # Archives a Vendor by ID.
  #
  # @path [PUT] /vendors/{id}/archive
  # @summary Archive a Vendor
  #
  # @parameter terminated_at [date-time] The date this vendor was terminated.
  #
  # @response_type [Vendor]
  # @summary Archive a Vendor
  #
  # @response 404 Resource not found
  # @response 403 Forbidden
  # @response 401 Unauthorized
  # @response 400 Bad Request
  #
  def archive
    company_vendor_id = params[:id]
    terminated_at = params[:terminated_at] || ""

    outcome = run(
      CompanyVendors::Archive,
      company_vendor_id: company_vendor_id,
      company_user_id: @api_key.owner_id,
      terminated_at: Date.parse(terminated_at).to_s
    )

    render_interaction_outcome(outcome)
  end
end
