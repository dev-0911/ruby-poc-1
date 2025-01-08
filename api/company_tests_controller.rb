# frozen_string_literal: true

# @resource Test
#
# This document describes the API for reading and updating Tests.
#
# @tag_group Endpoints
# @authorize_with header_authorization
#
class Api::CompanyTestsController < Api::BaseController
  DEFAULT_QUERY_PARAMS = [
    {term: {latest_version: true}},
    {term: {promoted: true}},
    {term: {visible: true}}
  ].freeze

  DEFAULT_RAILS_INCLUDES = [:attached_evidences, :owner, :promoted_by, {test_v2: :vendor}]

  PERMISSION_REQUIRED = Permission::TESTS

  ##
  # Returns a list of Tests.
  #
  # @path [GET] /tests
  # @summary List Tests
  #
  # @parameter page          [integer] Used for pagination of response data (default: page 1). Specifies the offset of the next block of data to receive.
  # @parameter per_page      [integer] Used for pagination of response data (default: 1000 items per response). Specifies the number of results for a given page.
  # @parameter relationships [boolean] Set to true to return the associated relationships data within the response. (default: false)
  # @parameter include       [boolean] Set to true along with relationships to return the entire relationship data in the `included` key within the response.
  # @parameter q             [string]  Search and filter the Test data using Lucene syntax.
  #
  # @response_type           [array<Test>]
  #
  # @response 403 Forbidden
  # @response 401 Unauthorized
  # @response 400 Bad Request
  #
  def index
    super
  end

  ##
  # Returns a Test by ID
  #
  # @path [GET] /tests/{id}
  # @summary Get a Test
  #
  # @response_type [Test]
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
  # Update a Test by ID
  #
  # @path [PUT] /tests/{id}
  # @summary Update a Test
  #
  # @parameter enabled                          [boolean]                     true or false for whether this test should be enabled or disabled.
  # @parameter disabled_justification           [string]                      The justification reason for why this test is disabled.
  # @parameter passed_with_upload_justification [string]                      The justification reason for why this test is passed with upload.
  # @parameter owner_id                         [uuid]                        The UUID of a user.
  # @parameter tolerance_window_seconds         [enum<{Duration::DURATIONS}>] The tolerance window representation for a test to be at risk.
  # @parameter next_due_date                    [date-time]                   Date time in ISO8601 format.
  # @parameter test_interval_seconds            [enum<{Duration::DURATIONS}>] How often the test should be run.
  # @parameter promote_at                       [date-time]                   Date time in ISO8601 format.
  #
  # @response_type [Test]
  #
  # @response 404 Resource not found
  # @response 403 Forbidden
  # @response 401 Unauthorized
  # @response 400 Bad Request
  #
  def update
    super
  end

  # @visibility private
  private def set_update_interaction_variables(valid_params:)
    variables = variables_for_update_interaction
    variables[:company_user_id] = @api_key.owner_id
    variables[:company_test] = @resource
    variables[:params] = valid_params
    variables
  end
end
