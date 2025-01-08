# frozen_string_literal: true

class Api::V1::CompanyUsersController < Api::V1::BaseController
  # authenticate_api_key!
  # GET /api/v1/company_users
  def index
    serialized = CompanyUser.for_api(
      Api::V1::CompanyUserIndexSerializer,
      @api_key.company_id,
      index_params(include: Api::V1::CompanyUserIndexSerializer::INCLUDE_PARAMS)
    )
    render(json: serialized.serializable_hash.to_json)
  end

  # authenticate_api_key!
  # GET /api/v1/company_users/:id
  def show
    serialized = CompanyUser.for_api_find(Api::V1::CompanyUserShowSerializer, @api_key.company_id, show_params)
    render(json: serialized.serializable_hash.to_json)
  rescue ActiveRecord::RecordNotFound
    render(json: {message: I18n.t("api.models.errors.not_found", model: I18n.t("api.models.company_user"))}, status: 404)
  end
end
