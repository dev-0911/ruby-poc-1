# frozen_string_literal: true

module Demo
  class DemoController < BaseController
    # POST /demo/companies
    def create_demo_company
      Seeds::DemoCompanyCreateJob.perform_async(
        demo_company_creation_params[:admin_email],
        demo_company_creation_params[:company_name]
      )
      generate_response(
        message: "Successfully created demo company",
        status: 200
      ) && return
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid, ActiveInteraction::Error, ArgumentError => e
      Rails.logger.error(e.message)
      generate_response(message: e.message, status: 400) && return
    end

    # DELETE /demo/companies
    def delete_company
      company_id = demo_company_deletion_params[:company_id]
      if Company.find_by(id: company_id)
        Seeds::DemoCompanyDeleteJob.perform_async(company_id)
        generate_response(
          message: "Successfully deleted demo company",
          status: 200
        ) && return
      else
        generate_response(
          message: "not found",
          status: 404,
          data: {company_id: company_id, company_name: company_name}
        ) && return
      end
    end

    private

    def generate_response(message:, status:, data: {})
      render(json: {message: message, **data}, status: status)
    end

    def demo_company_creation_params
      params.permit(
        :admin_email,
        :company_name
      )
    end

    def demo_company_deletion_params
      params.permit(
        :company_id,
        :company_name
      )
    end
  end
end
