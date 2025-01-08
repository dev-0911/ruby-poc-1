# frozen_string_literal: true

class OneSchema::ValidationsController < ApplicationController
  http_basic_authenticate_with name: "", password: Rails.configuration.oneschema_validation_api_key
  skip_before_action :verify_authenticity_token, raise: false
  respond_to :json
  before_action :decode_jwt

  # POST /oneschema/validations/bulk_risk_import
  def bulk_risk_import
    validator = OneSchemaValidations::BulkRiskImport.new(
      bulk_risk_import_params.to_h[:rows],
      @current_company
    )
    render(json: validator.validate, status: 200)
  end

  # POST /oneschema/validations/bulk_control_import
  def bulk_control_import
    validator = OneSchemaValidations::BulkControlImport.new(
      bulk_control_import_params.to_h[:rows],
      @current_company
    )
    render(json: validator.validate, status: 200)
  end

  # POST /oneschema/validations/bulk_control_mapping
  def bulk_control_mapping
    validator = OneSchemaValidations::BulkControlMapping.new(
      bulk_control_mapping_params.to_h["rows"],
      @current_company
    )
    render(json: validator.validate, status: 200)
  end

  # POST /oneschema/validations/create_custom_framework
  def create_custom_framework
    validator = OneSchemaValidations::CreateCustomFramework.new(
      create_custom_framework_params.to_h["rows"],
      @current_company
    )
    render(json: validator.validate, status: 200)
  end

  # POST /oneschema/validations/bulk_create_vendor_risk_template_questions
  def bulk_create_vendor_risk_template_questions
    validator = OneSchemaValidations::VendorRiskTemplateQuestionImport.new(
      vendor_risk_template_params.to_h["rows"],
      @current_company
    )
    render(json: validator.validate, status: 200)
  end

  private

  def bulk_risk_import_params
    params.permit(rows: [
      :row_id,
      {
        values: [
          :categories,
          :customRiskId,
          :departments,
          :email,
          :impact,
          :likelihood,
          :residualImpact,
          :residualLikelihood
        ]
      }
    ])
  end

  def bulk_control_import_params
    params.permit(rows: [:row_id, {values: [:key, :name, :description, :frameworkRequirementKeys]}])
  end

  def bulk_control_mapping_params
    params.permit(rows: [:row_id, {values: [:controlV2Key, :frameworkRequirementKeys]}])
  end

  def create_custom_framework_params
    params.permit(rows: [
      :row_id,
      {
        values: [
          :frameworkRequirementKey,
          :frameworkRequirementName,
          :frameworkRequirementDescription
        ]
      }
    ])
  end

  def vendor_risk_template_params
    params.permit(rows: [
      :row_id,
      {
        values: [
          :question,
          :category
        ]
      }
    ])
  end

  def decode_jwt
    token = JSON.parse(request.raw_post)["embed_user_jwt"]
    decoded_token = JWT.decode(token, Rails.configuration.oneschema_client_secret, true, {algorithm: "HS256"})
    @current_company_user = CompanyUser.find(decoded_token[0]["user_id"])
    @current_company = @current_company_user.company
  end
end
