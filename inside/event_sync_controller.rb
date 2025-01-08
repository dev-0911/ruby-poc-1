# frozen_string_literal: true

module Inside
  class EventSyncController < BaseController
    rescue_from StandardError, with: :server_error

    # POST /inside/event_sync/cloud_task_completion
    def cloud_task_completion
      unless (account_id = CompleteCloudSyncJob.new.get_environment_value(params[:notification], "SF_CONNECTION_ACCOUNT_ID"))
        render(
          json: "missing SF_CONNECTION_ACCOUNT_ID",
          status: 422
        )
        return
      end

      company = CompanyVendorConnection.find_by(account_id: account_id).company
      if company.feature_flag_enabled?(FeatureFlag::CLOUD_SYNC_V2_ENABLED)
        render(
          json: CompleteCloudSyncJob.perform_async(params[:notification]),
          status: 200
        )
      else
        render(
          json: "Feature not enabled",
          status: 200
        )
      end
    end

    # GET /inside/event_sync/auth_info
    def auth_info
      account_id = params[:account_id]
      connection = CompanyVendorConnection.find_by(account_id: account_id)
      render(
        json: connection&.vendor_authentication,
        status: 200
      )
    end

    private def server_error(error)
      render json: error.to_s, status: 500
    end
  end
end
