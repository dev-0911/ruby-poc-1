# frozen_string_literal: true

# @resource Trust Center Request
#
# This document describes the API for reading and updating Trust Center Requests.\
# Note: In order to access this API, you need to have paid features enabled for Trust.
#
# @tag_group Endpoints
# @authorize_with header_authorization
#
class Api::TrustCenterRequestsController < Api::BaseController
  before_action :authorize_trust_center_tier

  DEFAULT_QUERY_PARAMS = [
    {term: {discarded: false}}
  ].freeze

  PERMISSION_REQUIRED = Permission::TRUST_CENTER

  ##
  # Returns a list of Trust Center Requests
  #
  # @path [GET] /trust_center_requests
  # @summary List Trust Center Requests
  #
  # @parameter page          [integer] Used for pagination of response data (default: page 1). Specifies the offset of the next block of data to receive.
  # @parameter per_page      [integer] Used for pagination of response data (default: 1000 items per response). Specifies the number of results for a given page.
  # @parameter relationships [boolean] Set to true to return the associated relationships data within the response. (default: false)
  # @parameter include       [boolean] Set to true along with relationships to return the entire relationship data in the `included` key within the response.
  # @parameter q             [string]  Search and filter the Trust Center Request data using Lucene syntax.
  #
  # @response_type [array<TrustCenterRequest>]
  #
  # @response 403 Forbidden
  # @response 401 Unauthorized
  # @response 400 Bad Request
  #
  def index
    super
  end

  ##
  # Returns a single Trust Center Request by ID
  #
  # @path [GET] /trust_center_requests/{id}
  # @summary Get a Trust Center Request
  #
  # @response_type [TrustCenterRequest]
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
  # Update a TrustCenterRequest by ID
  #
  # @path [PUT] /trust_center_requests/{id}
  # @summary Update a Trust Center Request
  #
  # @parameter approved_trust_center_resource_request_ids [array<uuid>]                                   The IDs of the trust center resource requests for approval. Empty array will reject the request
  # @parameter rejected_trust_center_resource_request_ids [array<uuid>]                                   The IDs of the trust center resource requests for rejection.
  # @parameter document_security                          [enum<{TrustCenterRequest::DOCUMENT_SECURITY}>] The document security level for this trust center request.
  # @parameter file                                       [file]                                          The signed trust center nda agreement pdf file.
  # @parameter approve_all_resources                      [boolean]                                       Approve all resources for this trust center request.
  #
  # @response_type [TrustCenterRequest]
  #
  # @response 404 Resource not found
  # @response 403 Forbidden
  # @response 401 Unauthorized
  # @response 400 Bad Request
  #
  def update
    super
  end

  private def authorize_trust_center_tier
    return if @api_key.company.trust_paid_features_enabled?

    render(json: {message: I18n.t("api.controllers.errors.upgrade_required")}, status: 402)
  end

  private def set_update_interaction_variables(valid_params:)
    variables = variables_for_update_interaction
    variables[:current_company_user] = @api_key.owner
    variables[:trust_center_request_id] = @resource.id
    variables[:attributes] = valid_params
    variables[:attributes][:ip_address] = request.remote_ip
    variables[:attributes][:file] = valid_params[:file] if valid_params[:file].present?

    variables
  end

  private def valid_update_params
    params.permit([
      :document_security,
      :file,
      :approve_all_resources,
      approved_trust_center_resource_request_ids: [],
      rejected_trust_center_resource_request_ids: []
    ])
  end
end
