# frozen_string_literal: true

# @resource Integration Connection
#
# This document describes the API for reading and archiving Integration Connections.
#
# @tag_group Endpoints
# @authorize_with header_authorization
#
class Api::CompanyVendorConnectionsController < Api::BaseController
  before_action :load_and_authorize_resource, only: [:archive, :show]

  DEFAULT_QUERY_PARAMS = [
    {term: {archived: false}},
    {terms: {
      status: [CompanyVendorConnection::CONNECTED, CompanyVendorConnection::DISABLED, CompanyVendorConnection::PENDING]
    }}
  ].freeze

  DEFAULT_RAILS_INCLUDES = [:vendor]

  PERMISSION_REQUIRED = Permission::INTEGRATIONS

  ##
  # Returns a list of Integration Connections.
  #
  # @path [GET] /integration_connections
  # @summary List Integration Connections
  #
  # @parameter page          [integer] Used for pagination of response data (default: page 1). Specifies the offset of the next block of data to receive.
  # @parameter per_page      [integer] Used for pagination of response data (default: 1000 items per response). Specifies the number of results for a given page.
  # @parameter relationships [boolean] Set to true to return the associated relationships data within the response. (default: false)
  # @parameter include       [boolean] Set to true along with relationships to return the entire relationship data in the `included` key within the response.
  # @parameter q             [string]  Search and filter the Integration Connection data using Lucene syntax.
  #
  # @response_type [array<IntegrationConnection>]
  #
  # @response 403 Forbidden
  # @response 401 Unauthorized
  # @response 400 Bad Request
  #
  def index
    super
  end

  ##
  # Returns an Integration Connection by ID
  #
  # @path [GET] /integration_connections/{id}
  # @summary Get an Integration Connection
  #
  # @response_type [IntegrationConnection]
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
  # Archives an Integration Connection by ID.
  #
  # @path [PUT] /integration_connections/{id}/archive
  # @summary Archive an Integration Connection
  #
  # @response_type [IntegrationConnection]
  #
  # @response 404 Resource not found
  # @response 403 Forbidden
  # @response 401 Unauthorized
  # @response 400 Bad Request
  #
  def archive
    company_vendor_connection_id = params[:id]

    outcome = run(
      CompanyVendorConnections::Archive,
      connection_id: company_vendor_connection_id,
      delete_users: false
    )

    render_interaction_outcome(outcome)
  end
end
