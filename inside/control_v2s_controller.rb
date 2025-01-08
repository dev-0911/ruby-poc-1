module Inside
  class ControlV2sController < BaseController
    # POST /inside/control_v2s
    def create
      outcome = ControlV2s::Create.run(params.permit(
        :company_id,
        :framework_requirement_id,
        :description,
        :domain,
        :key,
        :name
      ))

      if outcome.valid?
        render(json: {message: "Successfully created control v2"}, status: 200)
      else
        render(json: {message: outcome.errors.full_messages.to_sentence}, status: 400)
      end
    end

    # PATCH /inside/control_v2s
    def update_bulk
      errors = []

      bulk_control_v2s_params[:control_v2s].each do |control_param|
        outcome = ControlV2s::Update.run(id: control_param[:id], params: control_param.to_h.except(:id))
        errors << outcome.errors.full_messages.to_sentence unless outcome.valid?
      end

      if errors.empty?
        render(json: {message: "Successfully updated ControlV2s"}, status: 200)
      else
        render(json: {message: errors}, status: 400)
      end
    end

    # DELETE /inside/control_v2s/:id
    def destroy
      outcome = ControlV2s::Delete.run(params.permit(:id))

      if outcome.valid?
        render(json: {message: "Successfully deleted framework requirement"}, status: 200)
      else
        render(json: {message: outcome.errors.full_messages.to_sentence}, status: 400)
      end
    end

    private

    def bulk_control_v2s_params
      params.permit(
        control_v2s: [
          :id,
          :name,
          :description,
          :key,
          :domain
        ]
      )
    end
  end
end
