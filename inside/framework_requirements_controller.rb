module Inside
  class FrameworkRequirementsController < BaseController
    # POST /inside/framework_requirements
    def create
      outcome = FrameworkRequirements::Create.run(params: params.permit(
        :framework_id,
        :section_id,
        :description,
        :key,
        :name,
        :position
      ).to_h)

      if outcome.valid?
        render(json: {message: "Successfully created framework requirement"}, status: 200)
      else
        render(json: {message: outcome.errors.full_messages.to_sentence}, status: 400)
      end
    end

    # PATCH /inside/framework_requirements
    def update_bulk
      errors = []

      bulk_framework_requirements_params[:framework_requirements].each do |req_param|
        outcome = FrameworkRequirements::Update.run(id: req_param[:id], params: req_param.to_h.except(:id))
        errors << outcome.errors.full_messages.to_sentence unless outcome.valid?
      end

      if errors.empty?
        render(json: {message: "Successfully updated framework requirements"}, status: 200)
      else
        render(json: {message: errors}, status: 400)
      end
    end

    # DELETE /inside/framework_requirements/:id
    def destroy
      outcome = FrameworkRequirements::Delete.run(params.permit(:id))

      if outcome.valid?
        render(json: {message: "Successfully deleted framework requirement"}, status: 200)
      else
        render(json: {message: outcome.errors.full_messages.to_sentence}, status: 400)
      end
    end

    private

    def bulk_framework_requirements_params
      params.permit(
        framework_requirements: [
          :id,
          :framework_id,
          :section_id,
          :name,
          :description,
          :key,
          :position,
          :justification_for_inclusion
        ]
      )
    end
  end
end
