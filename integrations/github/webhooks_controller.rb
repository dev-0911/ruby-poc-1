module Integrations
  module Github
    class WebhooksController < Integrations::ApplicationController
      skip_before_action :verify_authenticity_token

      def create
        logger.debug "---- received event #{request.env["HTTP_X_GITHUB_EVENT"]}"
        # TODO: handle uninstallation of apps and other relevant events
      end
    end
  end
end
