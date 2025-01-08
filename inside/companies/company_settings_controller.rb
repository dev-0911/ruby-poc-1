# frozen_string_literal: true

module Inside
  module Companies
    class CompanySettingsController < BaseController
      def sso_enabled
        company_id = params[:company_id]
        company = Company.find(company_id)

        render(json: {sso_enabled: company.sso_enabled?}, status: 200)
      rescue ActiveRecord::RecordNotFound
        render(json: {message: "Company not found for ID #{params[:company_id]}"}, status: 404) && return
      end
    end
  end
end
