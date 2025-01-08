# frozen_string_literal: true

# @resource User
#
# This document describes the API for reading and updating Users.
#
# @tag_group Endpoints
# @authorize_with header_authorization
#
class Api::CompanyUsersController < Api::BaseController
  before_action :authorize_update_user, only: [:update]

  DEFAULT_RAILS_INCLUDES = [:access_role, :user, {manager: :user}]

  PERMISSION_REQUIRED = Permission::PERSONNEL

  ##
  # Returns a list of Users.
  #
  # @path [GET] /users
  # @summary List Users
  #
  # @parameter page          [integer] Used for pagination of response data (default: page 1). Specifies the offset of the next block of data to receive.
  # @parameter per_page      [integer] Used for pagination of response data (default: 1000 items per response). Specifies the number of results for a given page.
  # @parameter relationships [boolean] Set to true to return the associated relationships data within the response. (default: false)
  # @parameter include       [boolean] Set to true along with relationships to return the entire relationship data in the `included` key within the response.
  # @parameter q             [string]  Search and filter the user data using Lucene syntax.
  #
  # @response_type           [array<User>]
  #
  # @response 403 Forbidden
  # @response 401 Unauthorized
  # @response 400 Bad Request
  #
  def index
    super
  end

  ##
  # Returns a User by ID
  #
  # @path [GET] /users/{id}
  #
  # @response_type [User]
  # @summary Get a User
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
  # Update a User by ID
  #
  # @path [PUT] /users/{id}
  # @summary Update a User
  #
  # @parameter active         [boolean]                             True if the user account is active, false if it has been disabled.
  # @parameter employee_type  [enum<{CompanyUser::EMPLOYEE_TYPES}>] The type of employee.
  # @parameter end_date       [date-time]                           Date when the user's employement ended in ISO 8601 format.
  # @parameter in_audit_scope [boolean]                             True if the user should be audited, false otherwise - only updateable in certain cases.
  # @parameter start_date     [date-time]                           Date when the user's employement started in ISO 8601 format.
  #
  # @response_type [User]
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
    variables[:id] = @resource.id
    variables[:params] = valid_params
    variables
  end

  private def valid_update_params
    params.permit(:active, :employee_type, :end_date, :in_audit_scope, :start_date)
  end

  private def authorize_update_user
    authorize_resource(User, @resource.user_id, :update, I18n.t("api.models.company_user"))
  end
end
