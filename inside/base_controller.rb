# frozen_string_literal: true

module Inside
  class BaseController < ApplicationController
    http_basic_authenticate_with name: Rails.application.config.inside_api_key, password: ""
    skip_before_action :verify_authenticity_token, raise: false
    respond_to :json
  end
end
