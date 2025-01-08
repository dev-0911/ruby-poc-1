# frozen_string_literal: true

module Integrations
  class ApiController < ApplicationController
    skip_before_action :verify_authenticity_token
  end
end
