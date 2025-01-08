# frozen_string_literal: true

module Inside
  class ConnectionsController < BaseController
    # POST /inside/connections/:id/disable
    def disable_connection
      connection = CompanyVendorConnection.find(params[:id])
      CompanyVendorConnections::Update.run!(id: connection.id, params: {status: CompanyVendorConnection::DISABLED})
      render(json: {message: "Successfully disabled connection"}, status: 200) && return
    rescue ActiveRecord::RecordNotFound
      render(json: {message: "CompanyVendorConnection not found for ID #{params[:id]}"},
        status: 404) && return
    rescue ActiveRecord::RecordInvalid, ActiveInteraction::Error, ArgumentError => e
      render(json: {message: e.message}, status: 400) && return
    end

    # DELETE /inside/connections/:id
    def delete_connection
      connection_id = params[:id]
      connection = CompanyVendorConnection.find(connection_id)
      connection.destroy!
      render(json: {id: connection_id, message: "Company vendor connection deleted"}, status: 200) && return
    rescue ActiveRecord::RecordNotFound
      render(json: {message: "Connection not found for ID #{connection_id}"}, status: 404) && return
    rescue ActiveRecord::RecordNotDestroyed => e
      render(json: {message: "Not Deleted: #{e.message}"}, status: 400) && return
    rescue ActiveRecord::RecordInvalid, ActiveInteraction::Error, ArgumentError => e
      render(json: {message: e.message}, status: 400) && return
    end

    # POST /inside/connections/:id/archive
    def archive_connection
      connection_id = params[:id]
      connection = CompanyVendorConnection.find(connection_id)
      connection.archive!
      render(json: {id: connection_id, message: "Successfully archived connection"}, status: 200) && return
    rescue ActiveRecord::RecordNotFound
      render(json: {message: "Connection not found for ID #{connection_id}"}, status: 404) && return
    rescue Archive::Errors::RecordNotArchived => e
      render(json: {message: "Not Archived: #{e.message}"}, status: 400) && return
    rescue ActiveRecord::RecordInvalid, ActiveInteraction::Error, ArgumentError => e
      render(json: {message: e.message}, status: 400) && return
    end

    # POST /inside/connections/:id/sync
    def sync_connection
      connection_id = params[:id]
      connection = CompanyVendorConnection.find(connection_id)
      connection.sync_async(SyncJobRun::USER)
      render(json: {id: connection_id, message: "Successfully triggered sync for connection"}, status: 200) && return
    rescue ActiveRecord::RecordNotFound
      render(json: {message: "Connection not found for ID #{connection_id}"}, status: 404) && return
    rescue ActiveRecord::RecordInvalid, ActiveInteraction::Error, ArgumentError => e
      render(json: {message: e.message}, status: 400) && return
    end
  end
end
