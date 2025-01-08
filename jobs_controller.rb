class JobsController < ApplicationController
  # webhooks don't have CSRF tokens
  skip_before_action :verify_authenticity_token

  before_action :authorize

  def run_job
    # Triggered by run_job lambda on us-west-2:
    #
    # require 'net/http'
    # require 'uri'
    # require 'openssl'

    # def lambda_handler(event:, context:)
    #     return { statusCode: 500, body: "account_id required" } unless event["account_id"]
    #
    #     uri = URI("https://beta.secureframe.com/jobs/#{event["account_id"]}")
    #     time = Time.now.to_i
    #     signature = OpenSSL::HMAC.hexdigest(
    #       OpenSSL::Digest.new('sha1'),
    #       ENV["SECRET"],
    #       time.to_s
    #     )
    #     response = Net::HTTP.post_form(
    #       uri,
    #       time: time,
    #       signature: signature
    #     )

    #     { statusCode: response.code, body: response.body }
    # end

    account_id = params[:account_id]
    connection = CompanyVendorConnection.find_by(account_id: account_id)
    return(render(json: {response: "CompanyVendorConnection not found"}, status: 404)) if connection.nil?

    response = connection.sync_async(SyncJobRun::USER)

    render(json: {response: response}, status: 200)
  end

  private

  def authorize
    head(:forbidden) unless valid_signature?
  end

  def valid_signature?
    return false unless Time.at(params[:time].to_i).between?(10.seconds.ago, 10.seconds.since)

    signature = OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new("sha1"),
      Rails.application.config.jobs_webhook_secret,
      params[:time]
    )
    Rack::Utils.secure_compare(signature, params[:signature])
  end
end
