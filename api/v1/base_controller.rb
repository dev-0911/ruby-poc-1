# frozen_string_literal: true

class Api::V1::BaseController < ApplicationController
  before_action :authenticate_api_key!
  before_action :set_datadog_span
  respond_to :json

  def authenticate_api_key!
    if request.headers["Authorization"].blank?
      render(json: {message: I18n.t("api.controllers.errors.unauthorized")}, status: 401)
      return
    end
    token = request.headers["Authorization"].presence
    id, secret = token.split(" ")
    if id.blank? || secret.blank?
      render(json: {message: I18n.t("api.controllers.errors.unauthorized")}, status: 401)
      return
    end
    api_key = ApiKey.find_by(id: id, revoked_at: nil)&.authenticate_key(secret)
    if api_key.blank?
      render(json: {message: I18n.t("api.controllers.errors.unauthorized")}, status: 401)
      return
    end
    unless FeatureFlag.instance.enabled_for_company?(FeatureFlag::SECUREFRAME_APIS_ENABLED, api_key.company)
      render(json: {message: I18n.t("api.controllers.errors.unauthorized")}, status: 401)
      return
    end
    @api_key ||= api_key
  end

  def index
    render(json: {message: I18n.t("api.controllers.errors.url_not_found")}, status: 404)
  end

  private def index_params(query: {}, include: {})
    params.permit(
      :page,
      :per,
      query,
      include
    )
  end

  # Make sure that set the relevant span information for user_id, company_user_id, and company_id similar to how we
  # set them in graphql_controller.rb
  private def set_datadog_span
    Datadog::Tracing.active_span&.set_tags({
      "secureframe.user_id": @api_key.owner.user_id,
      "secureframe.company_user_id": @api_key.owner_id,
      "secureframe.company_id": @api_key.company_id
    })
  end

  private def show_params
    params.permit(:id)
  end
end
