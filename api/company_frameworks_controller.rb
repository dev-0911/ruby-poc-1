# frozen_string_literal: true

# @resource Framework
#
# This document describes the API for reading Frameworks.
#
# @tag_group Endpoints
# @authorize_with header_authorization
#
class Api::CompanyFrameworksController < Api::BaseController
  DEFAULT_QUERY_PARAMS = [
    {term: {framework_visible: true}}
  ].freeze

  DEFAULT_RAILS_INCLUDES = [:framework]

  PERMISSION_REQUIRED = Permission::FRAMEWORKS

  ##
  # Returns a list of Frameworks.
  #
  # @path [GET] /frameworks
  # @summary List Frameworks
  #
  # @parameter page          [integer] Used for pagination of response data (default: page 1). Specifies the offset of the next block of data to receive.
  # @parameter per_page      [integer] Used for pagination of response data (default: 1000 items per response). Specifies the number of results for a given page.
  # @parameter relationships [boolean] Set to true to return the associated relationships data within the response. (default: false)
  # @parameter include       [boolean] Set to true along with relationships to return the entire relationship data in the `included` key within the response.
  # @parameter q             [string]  Search and filter the Framework data using Lucene syntax.
  #
  # @response_type [array<Framework>]
  #
  # @response 403 Forbidden
  # @response 401 Unauthorized
  # @response 400 Bad Request
  #
  def index
    super
  end

  ##
  # Returns a Framework by ID
  #
  # @path [GET] /frameworks/{id}
  # @summary Get a Framework
  #
  # @response_type [Framework]
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
