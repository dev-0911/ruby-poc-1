# frozen_string_literal: true

# @resource Evidence
#
# This document describes the API for reading Evidence.
#
# @tag_group Endpoints
# @authorize_with header_authorization
#
class Api::EvidencesController < Api::BaseController
  PERMISSION_REQUIRED = Permission::DATA_ROOM

  ##
  # Returns a single Evidence by ID
  #
  # @path [GET] /evidences/{id}
  # @summary Get an Evidence
  #
  # @response_type [Evidence]
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
