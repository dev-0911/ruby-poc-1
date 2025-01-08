module Inside
  class ControlV2MembershipsController < BaseController
    # POST /inside/control_v2_memberships
    def create
      outcome = ControlV2Memberships::Create.run(params: params.permit(
        :company_id,
        :control_v2_id,
        :framework_requirement_id
      ).to_h)

      if outcome.valid?
        render(json: {message: "Successfully created control v2 membership"}, status: 200)
      else
        render(json: {message: outcome.errors.full_messages.to_sentence}, status: 400)
      end
    end

    # PATCH /inside/control_v2_memberships/:id
    def update
      outcome = ControlV2Memberships::Update.run(
        id: params[:id],
        params: params.permit(
          :company_id,
          :control_v2_id,
          :framework_requirement_id
        ).to_h
      )

      if outcome.valid?
        render(json: {message: "Successfully updated control v2 membership"}, status: 200)
      else
        render(json: {message: outcome.errors.full_messages.to_sentence}, status: 400)
      end
    end

    # DELETE /inside/control_v2_memberships/:id
    def destroy
      outcome = ControlV2Memberships::Delete.run(params.permit(:id))

      if outcome.valid?
        render(json: {message: "Successfully deleted control v2 membership"}, status: 200)
      else
        render(json: {message: outcome.errors.full_messages.to_sentence}, status: 400)
      end
    end
  end
end
