module Inside
  class ControlsController < BaseController
    # POST /inside/controls
    def create
      outcome = Controls::Create.run(control_params: control_params.to_h)
      if outcome.valid?
        render(json: {message: "Successfully created control"}, status: 200)
      else
        render(json: {message: outcome.errors.full_messages.to_sentence}, status: 400)
      end
    end

    # PATCH /inside/controls
    def update_bulk
      errors = []
      bulk_controls_params[:controls].each do |control_param|
        outcome = Controls::Update.run(control_id: control_param[:id], params: control_param.to_h.except(:id))
        errors << outcome.errors.full_messages.to_sentence unless outcome.valid?
      end

      if errors.empty?
        render(json: {message: "Controls successfully updated"}, status: 200)
      else
        render(json: {message: errors}, status: 400)
      end
    end

    # DELETE /inside/controls/:id
    def destroy
      outcome = Controls::Delete.run(id: params[:id])
      if outcome.valid?
        render(json: {message: "Successfully deleted control"}, status: 200)
      else
        render(json: {message: outcome.errors.full_messages.to_sentence}, status: 400)
      end
    end

    private

    def bulk_controls_params
      params.permit(
        controls: [
          :id,
          :name,
          :description,
          :key,
          :position,
          :section_id
        ]
      )
    end

    def control_params
      params.permit(
        :name,
        :description,
        :key,
        :position,
        :section_id
      )
    end
  end
end
