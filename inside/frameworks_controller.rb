# frozen_string_literal: true

module Inside
  class FrameworksController < BaseController
    # POST /inside/frameworks
    def create
      outcome = Frameworks::Create.run(framework_params.to_h)
      if outcome.valid?
        render(json: {message: "Successfully created framework"}, status: 200)
      else
        render(json: {message: outcome.errors.full_messages.to_sentence}, status: 400)
      end
    end

    # PATCH /inside/frameworks/:id
    def update
      outcome = Frameworks::Update.run(id: params[:id], params: framework_params.to_h)

      if outcome.valid?
        render(json: {message: "Successfully updated framework"}, status: 200)
      else
        render(json: {message: outcome.errors.full_messages.to_sentence}, status: 400)
      end
    end

    # DELETE /inside/frameworks/:id
    def destroy
      outcome = Frameworks::Delete.run(id: params[:id])

      if outcome.valid?
        render(json: {message: "Successfully deleted framework"}, status: 200)
      else
        render(json: {message: outcome.errors.full_messages.to_sentence}, status: 400)
      end
    end

    private

    def framework_params
      params.permit(
        :name,
        :description,
        :group_name,
        :label,
        :tag_label,
        :title,
        :icon,
        :key,
        :visible
      )
    end
  end
end
