module Inside
  class FeedbacksController < BaseController
    # PATCH /inside/feedbacks
    def update_bulk
      errors = []
      bulk_feedbacks_params[:feedbacks].each do |feedback_param|
        outcome = Feedbacks::Update.run(id: feedback_param[:id], params: feedback_param.to_h.except(:id))
        errors << outcome.errors.full_messages.to_sentence unless outcome.valid?
      end

      if errors.empty?
        render(json: {message: "Feedbacks successfully updated"}, status: 200)
      else
        render(json: {message: errors}, status: 400)
      end
    end

    private

    def bulk_feedbacks_params
      params.permit(
        feedbacks: [
          :id,
          :resolved,
          :resolved_at
        ]
      )
    end
  end
end
