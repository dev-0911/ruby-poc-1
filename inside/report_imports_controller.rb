module Inside
  class ReportImportsController < BaseController
    # POST /inside/report_imports
    def create
      report_import = ReportImports::Create.run(report_imports_params)
      if report_import.valid?
        render(json: {message: "Successfully created report import"}, status: 200)
      else
        render(json: {message: report_import.errors.full_messages.to_sentence}, status: 400)
      end
    end

    private

    def report_imports_params
      params.permit(:imported_by_email, :file, :file_name, :content_type, :file_type)
    end
  end
end
