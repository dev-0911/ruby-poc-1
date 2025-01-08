module Inside
  class CompanyLinksController < BaseController
    def index
      conditions = []
      from_company_query = params[:from_company_query]
      to_company_query = params[:to_company_query]
      company_links = CompanyLink.joins(:from_company, :to_company)

      if from_company_query.present?
        conditions << "companies.name ILIKE :from_company_query"
      end

      if to_company_query.present?
        conditions << "to_companies_company_links.name ILIKE :to_company_query"
      end

      company_links = company_links.select(
        "company_links.id AS id",
        "company_links.link_type AS link_type",
        "companies.id AS from_company_id",
        "companies.name AS from_company_name",
        "to_companies_company_links.id AS to_company_id",
        "to_companies_company_links.name AS to_company_name"
      )

      if conditions.present?
        company_links = company_links.where(
          conditions.join(" AND "),
          from_company_query: "%#{from_company_query}%",
          to_company_query: "%#{to_company_query}%"
        )
      end

      data = company_links.map do |company_link|
        %i[id link_type from_company_id from_company_name to_company_id to_company_name]
          .index_with do |attribute|
          company_link.public_send(attribute)
        end
      end

      render json: data.to_json
    end

    def create
      outcome = ::CompanyLinks::Create.run(company_link_params.to_h)

      if outcome.valid?
        render(json: {message: "Successfully created company link"}, status: 200)
      else
        errors = outcome.errors
        if errors.added?(:from_company, :not_found) || errors.added?(:to_company, :not_found)
          render(
            json: {
              message: (errors.full_messages_for(:from_company) + errors.full_messages_for(:to_company)).to_sentence,
              data: {
                from_company_id: company_link_params[:from_company_id],
                to_company_id: company_link_params[:to_company_id]
              }
            },
            status: 404
          )
        else
          render(json: {message: errors.full_messages.to_sentence}, status: 400)
        end
      end
    end

    def destroy
      outcome = ::CompanyLinks::Destroy.run(id: params[:id])

      if outcome.valid?
        render(json: {message: "Successfully destroyed company link"}, status: 200)
      else
        errors = outcome.errors
        render(
          json: {
            message: errors.full_messages.to_sentence,
            data: {company_link_id: params[:id]}
          },
          status: 404
        )
      end
    end

    private

    def company_link_params
      params.permit(:from_company_id, :to_company_id, :link_type)
    end
  end
end
