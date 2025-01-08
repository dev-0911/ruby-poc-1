# frozen_string_literal: true

# @resource Cloud Resource
#
# This document describes the API for reading Cloud Resources.
#
# @tag_group Endpoints
# @authorize_with header_authorization
#
class Api::CloudResourcesController < Api::BaseController
  before_action :authorize_owner, only: [:update]

  DEFAULT_QUERY_PARAMS = [
    {term: {archived: false}},
    {term: {discarded: false}}
  ].freeze

  DEFAULT_RAILS_INCLUDES = [{company_vendor: :vendor}]

  PERMISSION_REQUIRED = Permission::ASSET_INVENTORY

  ##
  # Returns a list of Cloud Resources.
  #
  # @path [GET] /cloud_resources
  # @summary List Cloud Resources
  #
  # @parameter page          [integer] Used for pagination of response data (default: page 1). Specifies the offset of the next block of data to receive.
  # @parameter per_page      [integer] Used for pagination of response data (default: 1000 items per response). Specifies the number of results for a given page.
  # @parameter relationships [boolean] Set to true to return the associated relationships data within the response. (default: false)
  # @parameter include       [boolean] Set to true along with relationships to return the entire relationship data in the `included` key within the response.
  # @parameter q             [string]  Search and filter the Cloud Resource data using Lucene syntax.
  #
  # @response_type [array<CloudResource>]
  #
  # @response 403 Forbidden
  # @response 401 Unauthorized
  # @response 400 Bad Request
  #
  def index
    super
  end

  ##
  # Returns a single Cloud Resource by ID
  #
  # @path [GET] /cloud_resources/{id}
  # @summary Get a Cloud Resource
  #
  # @response_type [CloudResource]
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
  # Update a Cloud Resource by ID
  #
  # @path [PUT] /cloud_resources/{id}
  # @summary Update a Cloud Resource
  #
  # @parameter owner_id                  [uuid]                                       ID of the User that's the owner of this Cloud Resource.
  # @parameter in_audit_scope            [boolean]                                    Flag to indicate if this Cloud Resource is in scope.
  # @parameter out_of_audit_scope_reason [enum<{Device::OUT_OF_AUDIT_SCOPE_REASONS}>] Out of scope reason if the Cloud Resource is not in scope.
  #
  # @response_type [CloudResource]
  #
  # @response 404 Resource not found
  # @response 403 Forbidden
  # @response 401 Unauthorized
  # @response 400 Bad Request
  #
  def update
    super
  end

  private def set_update_interaction_variables(valid_params:)
    variables = variables_for_update_interaction
    variables[:cloud_resource_id] = params[:id]
    variables[:attributes] = params.permit(*valid_params)
    variables
  end

  private def valid_update_params
    [:in_audit_scope, :out_of_audit_scope_reason, :owner_id]
  end
end
