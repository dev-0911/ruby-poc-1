# frozen_string_literal: true

module SecurityQuestionnaires
  class BaseController < ApplicationController
    skip_before_action :verify_authenticity_token, raise: false
    respond_to :json
  end
end
