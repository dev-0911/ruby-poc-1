# frozen_string_literal: true

# @resource User Evidence
#
# This document describes the API for creating Evidence for a User.
#
# @tag_group Endpoints
# @authorize_with header_authorization
#
class Api::CompanyUsers::EvidencesController < Api::BaseController
  before_action :valid_document_type, only: [:create]
  before_action :authorize_create_evidence, only: [:create]

  PERMISSION_REQUIRED = Permission::PERSONNEL

  ##
  # Uploads evidence for a User.
  #
  # @path [POST] /users/{user_id}/evidences
  # @summary Create a User Evidence
  #
  # @parameter user_id       [uuid] The id of the user to attach the evidence
  # @parameter document_type [enum<{Evidence::VALID_API_DOCUMENT_TYPES}>] The type of evidence being uploaded for this user
  # @parameter file          [file] File which you want to attach as evidence
  #
  # @response_type [Evidence]
  #
  # @response 404 Resource not found
  # @response 403 Forbidden
  # @response 401 Unauthorized
  # @response 400 Bad Request
  #
  def create
    super
  end

  private def authorize_create_evidence
    company_user_id = params[:user_id]
    return if company_user_id.blank?
    translation = I18n.t("api.models.#{CompanyUser.to_s.underscore}")
    authorize_resource(CompanyUser, company_user_id, :update, translation)
  end

  # This is pulled from the app/graphql/mutations/create_evidence.rb resolver.
  # Sadly app/interactions/evidences/create.rb is not tested, is used throughout the application, and cannot be easily
  # updated to remove logic. Ideally, we can update the interaction to be more flexible.
  private def set_create_interaction_variables(valid_params:)
    company = @api_key.company
    variables = variables_for_create_interaction
    variables[:company_user] = @api_key.owner
    variables[:document_type] = valid_params[:document_type]
    variables[:evidenceable] = CompanyUser.find(valid_params[:user_id])
    variables[:evidence_type] = valid_params[:document_type] # this is the same as evidence_type
    # Note: this is different than the mutation, due to the mutation having an input of [ApolloUploadServer::Upload],
    # but we have ActionDispatch::Http::UploadedFile instead.
    variables[:files] = [valid_params[:file]]
    variables[:parent_id] = company.root_file_node_id || company.company_settings.evidence_file_node_id
    variables
  end

  private def valid_create_params
    # We need to override the valid_create params to allow `user_id` and `file`.
    params.permit(:user_id, :file, input_type_create_klass_arguments)
  end

  private def valid_document_type
    unless Evidence::VALID_API_DOCUMENT_TYPES.include?(valid_create_params[:document_type])
      raise BadInputException,
        I18n.t("api.controllers.errors.input", input: valid_create_params[:document_type], variable: "document_type")
    end
  end
end
