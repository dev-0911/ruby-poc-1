# frozen_string_literal: true

require "httparty"

class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  def sendgrid
    # Sendgrid batches events every 30s
    # https://sendgrid.com/docs/for-developers/tracking-events/
    events = params["_json"]
    events.each do |event|
      next unless event["secureframe_id"]

      message = Email.find(event["secureframe_id"])
      current_events = message.events || []
      message.update!(status: event["event"], events: current_events + [event])
    end

    head :ok
  end

  # Northpass sends a webhook when a user is activated
  # Upon adding the webhook URL in the northpass dashboard, it will send an initial request with empty params to verify
  # the URL
  # Endpoint: https://app.secureframe.com/webhooks/northpass
  # https://developers.northpass.com/docs/getting-started-webhooks
  def northpass
    Rails.logger.info("#{self.class} - Northpass webhook received")
    Rails.logger.info("#{self.class} - Params: #{params}")

    northpass_user = params&.dig("data", "included", 0)
    northpass_id = northpass_user&.dig("id")
    company_user_id = northpass_user&.dig("attributes", "sso_uid")

    Rails.logger.info("#{self.class} - CompanyUser ID: #{company_user_id}")

    begin
      company_user = CompanyUser.find(company_user_id)
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error("#{self.class} - CompanyUser not found: #{company_user_id}")

      # Return 200 to Northpass to acknowledge the webhook otherwise it will disable the webhook
      return head :ok
    end

    endpoint = "https://api.northpass.com/v2/people/#{northpass_id}"
    headers = {
      "X-Api-Key" => Rails.application.config.northpass_api_key,
      "accept" => "application/json",
      "content-type" => "application/json"
    }
    body = {
      data: {
        attributes: {
          email: company_user.email,
          first_name: company_user.first_name,
          last_name: company_user.last_name
        }
      }
    }

    response = HTTParty.put(
      endpoint,
      body: body.to_json,
      headers: headers
    )

    Rails.logger.info("#{self.class} - Update people response: #{response}")

    head :ok
  end
end
