module Inside
  class SectionsController < BaseController
    # POST /inside/sections
    def create
      outcome = Sections::Create.run(params: section_params.to_h)
      if outcome.valid?
        render(json: {message: "Successfully created section"}, status: 200)
      else
        render(json: {message: outcome.errors.full_messages.to_sentence}, status: 400)
      end
    end

    # PATCH /inside/sections
    def update_bulk
      errors = []
      bulk_sections_params[:sections].each do |section_param|
        outcome = Sections::Update.run(section_id: section_param[:id], params: section_param.to_h.except(:id))
        errors << outcome.errors.full_messages.to_sentence unless outcome.valid?
      end

      if errors.empty?
        render(json: {message: "Sections successfully updated"}, status: 200)
      else
        render(json: {message: errors}, status: 400)
      end
    end

    # DELETE /inside/sections/:id
    def destroy
      section_id = params.require(:id)
      section = Section.find_by(id: section_id)

      if section.blank?
        render(json: {message: "Section with id #{section_id} cannot be found"}, status: 404)
      elsif !section.destroy
        render(json: {message: "Failed to delete section"}, status: 400)
      else
        render(json: {message: "Section successfully deleted"}, status: 200)
      end
    end

    private

    def bulk_sections_params
      params.permit(
        sections: [
          :id,
          :name,
          :description,
          :key,
          :parent_section_id,
          :report_id,
          :position
        ]
      )
    end

    def section_params
      params.permit(
        :name,
        :description,
        :key,
        :parent_section_id,
        :report_id,
        :position
      )
    end
  end
end
