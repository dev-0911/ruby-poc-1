# frozen_string_literal: true

# @resource Control
#
# This document describes the API for reading Controls.
#
# @tag_group Endpoints
# @authorize_with header_authorization
#
class Api::CompanyControlV2sController < Api::BaseController
  DEFAULT_RAILS_INCLUDES = [:author, :control_v2, :owner]

  PERMISSION_REQUIRED = Permission::CONTROLS

  ##
  # Returns a list of Controls.
  #
  # @path [GET] /controls
  # @summary List Controls
  #
  # @parameter page          [integer] Used for pagination of response data (default: page 1). Specifies the offset of the next block of data to receive.
  # @parameter per_page      [integer] Used for pagination of response data (default: 1000 items per response). Specifies the number of results for a given page.
  # @parameter relationships [boolean] Set to true to return the associated relationships data within the response. (default: false)
  # @parameter include       [boolean] Set to true along with relationships to return the entire relationship data in the `included` key within the response.
  # @parameter q             [string]  Search and filter the control data using Lucene syntax.
  #
  # @response_type           [array<Control>]
  #
  # @response 403 Forbidden
  # @response 401 Unauthorized
  # @response 400 Bad Request
  #
  def index
    super
  end

  ##
  # Returns a Control by ID
  #
  # @path [GET] /controls/{id}
  # @summary Get a Control
  #
  # @response_type [Control]
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
