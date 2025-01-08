module Inside
  class CompanyFrameworksController < BaseController
    # POST /inside/company_frameworks
    def create
      outcome = CompanyFrameworks::Create.run(params.permit(
        :company_id,
        :framework_id
      ))

      if outcome.valid?
        render(json: {message: "Successfully enabled framework"}, status: 200)
      else
        render(json: {message: outcome.errors.full_messages.to_sentence}, status: 400)
      end
    end

    # DELETE /inside/company_frameworks/:id
    def destroy
      outcome = CompanyFrameworks::Delete.run(params.permit(:id))

      if outcome.valid?
        render(json: {message: "Successfully disabled framework"}, status: 200)
      else
        render(json: {message: outcome.errors.full_messages.to_sentence}, status: 400)
      end
    end
  end
end
