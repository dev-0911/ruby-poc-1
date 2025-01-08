# frozen_string_literal: true

module Inside
  # TODO: custom-controls - Remove ReportsController
  class ReportsController < BaseController
    # POST /inside/reports
    def create
      outcome = Frameworks::Create.run(framework_params.to_h)
      if outcome.valid?
        render(json: {message: "Successfully created framework"}, status: 200)
      else
        render(json: {message: outcome.errors.full_messages.to_sentence}, status: 400)
      end
    end

    # PATCH /inside/reports/:id
    def update
      outcome = Frameworks::Update.run(id: params[:id], params: framework_params.to_h)

      if outcome.valid?
        render(json: {message: "Framework successfully updated"}, status: 200)
      else
        render(json: {message: outcome.errors.full_messages.to_sentence}, status: 400)
      end
    end

    # DELETE /inside/reports/:id
    def destroy
      if params[:skip_callbacks].present?
        Frameworks::DeleteWithoutCallbacksJob.perform_async(params[:id])
      else
        Frameworks::DeleteJob.perform_async(params[:id])
      end

      render(json: {message: "Successfully queued report deletion"}, status: 200)
    end

    # POST /inside/reports/:report_key/enablement
    def enable_report
      report_key = params[:report_key]
      company = Company.find(params[:company_id])
      framework = Report.find_by_key(report_key)

      if framework.nil?
        render(json: {message: "Report not found"}, status: 404) && return
      end
      framework_already_enabled = company.framework_enabled?(framework)
      render(json: {message: "Report already enabled"}, status: 400) && return if framework_already_enabled

      CompanyFrameworks::Create.run(
        company_id: company.id,
        framework_id: framework.id
      )

      render(json: {message: "Report successfully enabled"}, status: 200)
    end

    # POST /inside/reports/:report_key/disablement
    def disable_report
      report_key = params[:report_key]
      company = Company.find(params[:company_id])
      framework = Report.find_by_key(report_key)

      if framework.nil?
        render(json: {message: "Report not found"}, status: 404) && return
      end
      report_already_disabled = !company.framework_enabled?(framework)
      render(json: {message: "Report already disabled"}, status: 400) && return if report_already_disabled

      CompanyFrameworks::Delete.run(company_id: company.id, framework_id: framework.id)

      render(json: {message: "Report successfully disabled"}, status: 200)
    end

    private

    def framework_params
      params.permit(
        :name,
        :description,
        :group_name,
        :label,
        :title,
        :icon,
        :key,
        :visible
      )
    end
  end
end
