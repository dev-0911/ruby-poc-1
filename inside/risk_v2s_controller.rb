# frozen_string_literal: true

module Inside
  class RiskV2sController < BaseController
    # POST /inside/risk_v2s
    def create
      outcome = RiskV2s::Create.run(risk_v2_params: create_params.to_h)

      if outcome.valid?
        render(json: {message: "Successfully created risk"}, status: 200)
      else
        render(json: {message: outcome.errors.full_messages.to_sentence}, status: 400)
      end
    end

    # PATCH /inside/risk_v2s
    def update_bulk
      errors = []
      # params is an array of hashes
      bulk_update_params[:risk_v2s].each do |risk_v2_params|
        outcome = RiskV2s::Update.run(
          risk_v2_id: risk_v2_params[:id],
          risk_v2_params: risk_v2_params.to_h.except(:id)
        )
        errors << outcome.errors.full_messages.to_sentence unless outcome.valid?
      end

      if errors.empty?
        test_count = bulk_update_params[:risk_v2s].count
        render(json: {message: "Successfully updated #{test_count} tests"}, status: 200)
      else
        render(json: {message: errors}, status: 400)
      end
    end

    # DELETE /inside/risk_v2s/:id
    def destroy
      outcome = RiskV2s::Delete.run(
        risk_v2_id: delete_params[:id]
      )

      if outcome.valid?
        render(json: {message: "Successfully deleted risk with id: #{delete_params[:id]}"}, status: 200)
      else
        render(json: {message: outcome.errors.full_messages.to_sentence}, status: 400)
      end
    end

    private

    def generate_response(message:, status:, data: {})
      render(json: {message: message, **data}, status: status)
    end

    def create_params
      params.permit(
        :description,
        categories: []
      )
    end

    def bulk_update_params
      params.permit(
        risk_v2s: [
          :id,
          :description,
          categories: []
        ]
      ).except(:risk_v2)
    end

    def delete_params
      params.permit(
        :id
      )
    end
  end
end
