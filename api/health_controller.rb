# frozen_string_literal: true

class Api::HealthController < Api::BaseController
  skip_before_action :authenticate_api_key!
  skip_before_action :authorize_permission

  # GET /health
  def status
    render(json: {data: "ok"})
  end
end
