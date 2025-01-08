# frozen_string_literal: true

# @resource Device
#
# This document describes the API for reading Devices.
#
# @tag_group Endpoints
# @authorize_with header_authorization
#
class Api::DevicesController < Api::BaseController
  PERMISSION_REQUIRED = Permission::ASSET_INVENTORY

  ##
  # Returns a list of Devices.
  #
  # @path [GET] /devices
  # @summary List Devices
  #
  # @parameter page          [integer] Used for pagination of response data (default: page 1). Specifies the offset of the next block of data to receive.
  # @parameter per_page      [integer] Used for pagination of response data (default: 1000 items per response). Specifies the number of results for a given page.
  # @parameter relationships [boolean] Set to true to return the associated relationships data within the response. (default: false)
  # @parameter include       [boolean] Set to true along with relationships to return the entire relationship data in the `included` key within the response.
  # @parameter q             [string]  Search and filter the Device data using Lucene syntax.
  #
  # @response_type [array<Device>]
  #
  # @response 403 Forbidden
  # @response 401 Unauthorized
  # @response 400 Bad Request
  #
  def index
    super
  end

  ##
  # Returns a single Device by ID
  #
  # @path [GET] /devices/{id}
  # @summary Get a Device
  #
  # @response_type [Device]
  #
  # @response 404 Resource not found
  # @response 403 Forbidden
  # @response 401 Unauthorized
  # @response 400 Bad Request
  #
  def show
    super
  end
end
