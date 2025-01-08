# frozen_string_literal: true

# @resource Test Evidence
#
# This document describes the API for creating Evidence for a Test.
#
# @tag_group Endpoints
# @authorize_with header_authorization
#
class Api::CompanyTests::EvidencesController < Api::BaseController
  before_action :authorize_create_evidence, only: [:create]

  PERMISSION_REQUIRED = Permission::TESTS

  ##
  # Uploads evidence to a Test.
  #
  # @path [POST] /tests/{test_id}/evidences
  # @summary Create a Test Evidence
  #
  # @parameter test_id [uuid] The ID of the Test to attach the evidence
  # @parameter file    [file] File which you want to attach as evidence
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
    test_id = params[:test_id]
    return if test_id.blank?
    translation = I18n.t("api.models.#{CompanyTest.to_s.underscore}")
    authorize_resource(CompanyTest, test_id, :update, translation)
  end

  # This is pulled from the app/graphql/mutations/create_evidence.rb resolver.
  # Sadly app/interactions/evidences/create.rb is not tested, is used throughout the application, and cannot be easily
  # updated to remove logic. Ideally, we can update the interaction to be more flexible.
  private def set_create_interaction_variables(valid_params:)
    variables = variables_for_create_interaction
    variables[:attached_to] = CompanyTest.find(valid_params[:test_id])
    variables[:company_user] = @api_key.owner
    variables[:document_type] = Evidence::CUSTOM
    variables[:evidenceable] = @api_key.owner
    variables[:evidence_type] = Evidence::CUSTOM
    # Note: this is different than the mutation, due to the mutation having an input of [ApolloUploadServer::Upload],
    # but we have ActionDispatch::Http::UploadedFile instead.
    variables[:files] = [valid_params[:file]]
    # variables[:parent_id] = valid_params[:parent_id] # TBD: discuss with Nicky/Chintan if this is needed
    variables
  end

  private def valid_create_params
    # We need to override the valid_create params to allow `test_id` and `file`.
    params.permit(:test_id, :file, input_type_create_klass_arguments)
  end
end
