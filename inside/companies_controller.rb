module Inside
  class CompaniesController < BaseController
    def index
      @companies = Company.active.order(:name)
      if params[:search].present?
        @companies = @companies.where("name ILIKE ?", "%#{params[:search]}%")
      end

      render json: @companies.to_json(only: [:id, :name, :slug])
    end

    def promote
      company_id = params[:id]
      outcome = ::Companies::Promote.run(
        id: params[:id],
        promote: company_params[:promote],
        link_type: company_params[:link_type]
      )

      if outcome.valid?
        render(json: {message: "Successfully promoted"}, status: 200)
      else
        errors = outcome.errors
        if errors.added?(:company, :not_found)
          render(
            json: {
              message: errors.full_messages_for(:company).to_sentence,
              data: {company_id: company_id}
            },
            status: 404
          )
        else
          render(json: {message: errors.full_messages.to_sentence}, status: 400)
        end
      end
    end

    def sso_domains
      company_id = params[:id]
      sso_domains = params[:sso_domains] || []

      company = Company.find(company_id)

      outcome = ::Companies::Update.run(
        id: company.id,
        company_params: {sso_domains: sso_domains}
      )

      if outcome.valid?
        render(json: {message: "Successfully updated sso_domains"}, status: 200)
      else
        errors = outcome.errors
        render(json: {message: errors.full_messages.to_sentence}, status: 400)
      end
    rescue ActiveRecord::RecordNotFound
      render(json: {message: "Company not found for ID #{params[:id]}"}, status: 404) && return
    end

    # PATCH /inside/companies
    def update_bulk
      errors = []

      bulk_companies_params[:companies].each do |company_param|
        outcome = ::Companies::Update.run(id: company_param[:id], company_params: company_param.to_h.except(:id))
        errors << outcome.errors.full_messages.to_sentence unless outcome.valid?
      end

      if errors.empty?
        render(json: {message: "Successfully updated Companies"}, status: 200)
      else
        render(json: {message: errors}, status: 400)
      end
    end

    def sync_company_user_tasks
      company_id = params[:company_id]
      Tasks::SyncCompanyUserTasksJob.perform_async(company_id)

      render(json: {success: true, error_message: nil})
    end

    private

    def company_params
      params.permit(:promote, :link_type)
    end

    def bulk_companies_params
      params.permit(
        companies: [
          :id,
          :name,
          :legal_name,
          :domain,
          :description,
          :country_code,
          :phone_number,
          :privacy_policy_url,
          :terms_of_service_url,
          :customer_facing_url,
          :customer_contact_url,
          :entity_type,
          :founded_year,
          :ein,
          :country_of_incorporation,
          :state_of_incorporation,
          :security_email,
          :onboarding_status,
          :board_of_directors_count,
          :board_of_directors_meeting_frequency,
          :board_of_directors_names,
          :careers_page_url,
          :product_update_page_url,
          :security_page_url,
          :services_page_url,
          :billing_email,
          :vat,
          :overview_url,
          :update_url,
          :security_commitment_url,
          :sso_domains,
          :customer_success_manager_id
        ]
      )
    end
  end
end
