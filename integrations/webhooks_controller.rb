module Integrations
  class WebhooksController < ::Integrations::ApiController
    def create
      permitted_params = params.permit!
      vendor_slug = permitted_params.delete(:vendor_slug)
      resource_type = permitted_params.delete(:resource_type)
      account_id = permitted_params.delete(:account_id)

      outcome = Integrations::Base::WebhookReceiver.run(
        webhook_id: SecureRandom.uuid,
        vendor_slug: vendor_slug,
        resource_type: resource_type,
        account_id: account_id,
        payload: permitted_params.to_hash
      )

      if outcome.valid?
        head(:ok)
      else
        handle_webhook_receiver_outcome(outcome)
      end
    end

    private def handle_webhook_receiver_outcome(outcome)
      if outcome.errors.include?(:vendor_slug)
        head(422)
      elsif outcome.errors[:account_id]&.include?("is invalid")
        head(410)
      else
        head(500)
      end
    end
  end
end
