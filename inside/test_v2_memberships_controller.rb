module Inside
  class TestV2MembershipsController < BaseController
    # POST /inside/test_memberships
    def create
      outcome = TestV2Memberships::Create.run(test_membership_params)

      if outcome.valid?
        render(json: {message: "Successfully created TestV2Membership"}, status: 200)
      else
        render(json: {message: outcome.errors.full_messages.to_sentence}, status: 400)
      end
    end

    # DELETE /inside/test_memberships/:id
    def destroy
      outcome = TestV2Memberships::Delete.run(id: params[:id])

      if outcome.valid?
        render(json: {message: "Successfully deleted TestV2Membership"}, status: 200)
      else
        render(json: {message: outcome.errors.full_messages.to_sentence}, status: 400)
      end
    end

    private

    def test_membership_params
      params.permit(:test_v2_id, :control_id, :control_v2_id)
    end
  end
end
