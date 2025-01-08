module Inside
  class SecureframeAgentController < BaseController
    before_action :check_company_user_params, except: [:delete_company_builds]
    before_action :check_company_params, only: [:delete_company_builds]

    # GET /inside/secureframe_agent/get_user_builds_info
    def get_user_builds_info
      builds_found = SecureframeAgent::HeadAgentBuilds.run({company_user: @company_user}).result
      render(json: builds_found, status: 200)
    end

    # DELETE /inside/secureframe_agent/user_builds
    def delete_user_builds
      builds_deleted = SecureframeAgent::DeleteAgentBuilds.run({company_user: @company_user}).result
      render(json: {message: "Deleted these builds, if they existed: #{builds_deleted}"}, status: 200)
    end

    # DELETE /inside/secureframe_agent/company_builds
    def delete_company_builds
      SecureframeAgent::DeleteCompanyAgentBuilds.run({company: @company}).result
      Rails.logger.info(
        "Deleted all Agent builds for company #{@company.slug}"
      )

      render(json: {message: "Deleted all Agent builds for company #{@company.slug}"}, status: 200)
    end

    private

    def check_company_user_params
      company_user_id = params[:company_user_id]
      company_slug = params[:company_slug]
      email = params[:email]

      @company_user = if company_user_id.present? || (company_slug.present? && email.present?)
        company = Company.find_by_slug(company_slug)
        user_ids = User.where(email: email)&.pluck(:id)
        CompanyUser.where(id: company_user_id).or(
          CompanyUser.where(company_id: company&.id, user_id: user_ids)
        ).first
      else
        render(json: {message: "Need company_user_id or both company_slug and user email"}, status: 400)
        return
      end

      if @company_user.blank?
        render(
          json: {
            message: "CompanyUser not found, please double check inputs: #{company_user_id}, #{company_slug}, #{email}"
          },
          status: 404
        )
      end
    end

    def check_company_params
      company_slug = params[:company_slug]

      @company = if company_slug.present?
        Company.find_by_slug(company_slug)
      else
        render(json: {message: "Need company_slug"}, status: 400)
        return
      end

      if @company.blank?
        render(
          json: {
            message: "Company not found, please double check input: #{company_slug}"
          },
          status: 404
        )
      end
    end
  end
end
