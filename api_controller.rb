# frozen_string_literal: true

class ApiController < ApplicationController
  # Disclaimer: The whole design of this API was to get a quick and dirty
  # solution out for one of our customers. This is not how we should design
  # APIs going forward, and at some point this code should be removed in
  # favor of an actual, properly implemented, Secureframe API
  protect_from_forgery with: :null_session

  def create_azure_auth
    api_key = request.headers["X-API-KEY"]
    return head(:unauthorized) if api_key.nil?

    company = Company.find_by(api_key: api_key)
    return head(:unauthorized) if company.nil?

    vendor = Vendor.find_by(slug: "azure")
    Rails.logger.error("Failed to find Azure vendor")
    return head(:internal_server_error) if vendor.nil?

    if params[:subscription_id].blank?
      render(json: {errors: ["Missing Azure subscription id"]}, status: :unprocessable_entity) && return
    elsif params[:key_value].blank?
      render(json: {errors: ["Missing Azure secret key value"]}, status: :unprocessable_entity) && return
    elsif params[:directory_id].blank?
      render(json: {errors: ["Missing Azure directory id"]}, status: :unprocessable_entity) && return
    end

    outcome = CompanyVendorConnections::Create.run(params: {vendor_id: vendor.id, company_id: company.id})
    if outcome.errors.present?
      Rails.logger.error(outcome.errors)
      return head(:internal_server_error)
    end
    connection = outcome.result

    create_auth_response = SecureframeSchema.execute(
      create_azure_auth_query,
      variables: {
        accountId: connection.account_id,
        applicationId: params[:application_id],
        keyValue: params[:key_value],
        directoryId: params[:directory_id],
        subscriptionId: params[:subscription_id],
        location: params[:location]
      }
    )

    if create_auth_response["data"]["createAzureAuth"]["errors"].present?
      render(json: {errors: create_auth_response["data"]["createAzureAuth"]["errors"]},
        status: :unprocessable_entity)
      return
    end

    head(:ok)
  end

  def create_azure_auth_query
    <<~GRAPHQL
      mutation($accountId: String!, $applicationId: String!, $keyValue: String!, $directoryId: String!, $subscriptionId: String!, $location: String) {
        createAzureAuth(input: {accountId: $accountId, applicationId: $applicationId, keyValue: $keyValue, directoryId: $directoryId, subscriptionId: $subscriptionId, location: $location}) {
          errors
        }
      }
    GRAPHQL
  end

  def create_gcp_auth
    api_key = request.headers["X-API-KEY"]
    return head(:unauthorized) if api_key.nil?

    company = Company.find_by(api_key: api_key)
    return head(:unauthorized) if company.nil?

    vendor = Vendor.find_by(slug: "google_cloud")
    Rails.logger.error("Failed to find Google Cloud Platform vendor")
    return head(:internal_server_error) if vendor.nil?

    if params[:key_json].blank?
      render(json: {errors: ["Missing GCP Key JSON File"]}, status: :unprocessable_entity) && return
    end
    unless valid_json?(params[:key_json])
      render(json: {errors: ["GCP Key JSON file is invalid JSON"]}, status: :unprocessable_entity) && return
    end

    outcome = CompanyVendorConnections::Create.run(params: {vendor_id: vendor.id, company_id: company.id})
    if outcome.errors.present?
      Rails.logger.error(outcome.errors)
      return head(:internal_server_error)
    end
    connection = outcome.result

    create_auth_response = SecureframeSchema.execute(
      create_gcp_auth_query,
      variables: {
        accountId: connection.account_id,
        keyJson: params[:key_json]
      }
    )

    if create_auth_response["data"]["createGoogleCloudAuthWithApi"]["errors"].present?
      render(json: {errors: create_auth_response["data"]["createGoogleCloudAuthWithApi"]["errors"]},
        status: :unprocessable_entity)
      return
    end

    head(:ok)
  end

  def valid_json?(json_string)
    JSON.parse(json_string)
    true
  rescue JSON::ParserError
    false
  end

  def create_gcp_auth_query
    <<~GRAPHQL
      mutation($accountId: String!, $keyJson: JSON!) {
        createGoogleCloudAuthWithApi(input: {accountId: $accountId, keyJson: $keyJson}) {
          errors
        }
      }
    GRAPHQL
  end

  def create_aws_auth
    api_key = request.headers["X-API-KEY"]
    return head(:unauthorized) if api_key.nil?

    company = Company.find_by(api_key: api_key)
    return head(:unauthorized) if company.nil?

    vendor = Vendor.find_by(slug: "aws")
    Rails.logger.error("Failed to find Amazon Web Services vendor")
    return head(:internal_server_error) if vendor.nil?

    render(json: {errors: ["Missing role ARN"]}, status: :unprocessable_entity) && return if params[:role_arn].blank?
    selected_regions = params[:selected_regions] || []
    unless valid_aws_regions(selected_regions)
      render(json: {errors: ["Invalid AWS regions"]}, status: :unprocessable_entity) && return
    end

    outcome = CompanyVendorConnections::Create.run(params: {vendor_id: vendor.id, company_id: company.id})
    if outcome.errors.present?
      Rails.logger.error(outcome.errors)
      return head(:internal_server_error)
    end
    connection = outcome.result

    create_auth_response = SecureframeSchema.execute(
      create_aws_auth_query,
      variables: {
        accountId: connection.account_id,
        roleArn: params[:role_arn],
        skipRegions: selected_regions_to_skip_regions(selected_regions)
      }
    )

    if create_auth_response["data"]["createAwsAuth"]["errors"].present?
      render(json: {errors: create_auth_response["data"]["createAwsAuth"]["errors"]}, status: :unprocessable_entity)
      return
    end
    external_id = Integrations::VendorAuthentication.find_by(account_id: connection.account_id).data["external_id"]
    if external_id.blank?
      Rails.logger.error("No external id found for vendor auth with account id #{connection.account_id}")
      return head(:internal_server_error)
    end

    render json: {"external_id" => external_id}
  end

  def create_aws_auth_query
    <<~GRAPHQL
      mutation($accountId: String!, $roleArn: String!, $skipRegions: [String!]) {
        createAwsAuth(input: {accountId: $accountId, roleArn: $roleArn, skipRegions: $skipRegions}) {
          errors
        }
      }
    GRAPHQL
  end

  def valid_aws_regions(selected_regions)
    return true if selected_regions.nil?
    selected_regions.each do |region|
      return false unless Integrations::Aws::Connector::AWS_REGIONS.include?(region)
    end
    true
  end

  def selected_regions_to_skip_regions(selected_regions)
    return [] if selected_regions.nil?
    Integrations::Aws::Connector::AWS_REGIONS - selected_regions
  end
end
