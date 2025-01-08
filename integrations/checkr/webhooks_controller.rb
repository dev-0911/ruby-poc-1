# frozen_string_literal: true

module Integrations
  module Checkr
    class WebhooksController < Integrations::ApplicationController
      skip_before_action :verify_authenticity_token
      def create
        head(:ok)
      end
    end
  end
end
