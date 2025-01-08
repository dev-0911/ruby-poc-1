module Inside
  class TestV2sController < BaseController
    # GET /inside/test_v2s
    def index
      latest_version = params[:test_versions] == "latest"
      id = params[:id]
      include_versions = params[:include_versions] == "true"
      test_v2s = if latest_version
        TestV2.latest_versions
      elsif id && include_versions
        TestV2s::GetAllVersions.call(id)
      else
        TestV2.all
      end
      render(json: {test_v2s: test_v2s, message: "Successfuly retrieved TestV2s"}, status: 200)
    rescue ActiveRecord::RecordNotFound
      render(json: {message: "No TestV2s found"}, status: 400)
    end

    # POST /inside/test_v2s
    def create
      outcome = TestV2s::Create.run(input_params: test_v2_params.to_h)

      if outcome.valid?
        render(json: {message: "Successfully created test_v2"}, status: 200)
      else
        render(json: {message: outcome.errors.full_messages.to_sentence}, status: 400)
      end
    end

    # PATCH /inside/test_v2s/:id
    def update
      outcome = TestV2s::Update.run(
        test_v2_id: params[:id],
        input_params: test_v2_params.to_h,
        safe_update: params[:safe_update].in?(["true", true])
      )

      if outcome.valid?
        render(json: {message: "Successfully updated test_v2 with id: #{outcome.result.id}"}, status: 200)
      else
        render(json: {message: outcome.errors.full_messages.to_sentence}, status: 400)
      end
    end

    # PATCH /inside/test_v2s
    def update_bulk
      errors = []
      bulk_test_v2_params[:test_v2s].each do |test_v2_param|
        outcome = TestV2s::Update.run(
          test_v2_id: test_v2_param[:id],
          input_params: test_v2_param.to_h.except(:id),
          safe_update: params[:safe_update].in?(["true", true])
        )
        errors << outcome.errors.full_messages.to_sentence unless outcome.valid?
      end

      if errors.empty?
        render(json: {message: "Tests successfully updated"}, status: 200)
      else
        render(json: {message: errors}, status: 400)
      end
    end

    # DELETE /inside/test_v2s/:id
    def destroy
      outcome = TestV2s::Delete.run(
        id: params[:id],
        safe_delete: params[:safe_delete].in?(["true", true])
      )

      if outcome.valid?
        render(json: {message: "Successfully updated test_v2 with id: #{outcome.result.id}"}, status: 200)
      else
        render(json: {message: outcome.errors.full_messages.to_sentence}, status: 400)
      end
    end

    # POST /inside/test_v2s/versions
    def create_new_versions
      new_test_v2s_data = create_new_versions_params[:new_test_v2s_data].map do |test_v2_data|
        test_v2_data.to_h
      end

      job_id = Tests::CreateNewVersionsJob.perform_async(
        create_new_versions_params[:old_test_v2_id],
        new_test_v2s_data,
        create_new_versions_params[:change_description]
      )

      render(json: {message: "Successfully enqueued job (#{job_id}) to create new test_v2 versions and succession relations."}, status: 200)
    end

    # POST /inside/test_v2s/:id/promotion
    def promote
      company_test = CompanyTest.find_by(test_v2_id: params[:id], company_id: promotion_params[:company_id])

      if company_test.blank?
        render(
          json: {
            message: "Promotion of test_v2 (#{params[:id]}) for company (#{promotion_params[:company_id]}) failed"
          },
          status: 400
        )
        return
      end

      outcome = CompanyTests::Promote.run(company_test: company_test, company: company_test.company, should_transfer_evidence: true)

      if outcome.valid?
        render(
          json: {
            message: "Successfully promoted test_v2 (#{params[:id]}) for company (#{promotion_params[:company_id]})"
          },
          status: 200
        )
      else
        render(json: {message: outcome.errors.full_messages.to_sentence}, status: 400)
      end
    end

    # POST /inside/test_v2s/:id/release
    def release
      outcome = TestV2s::Release.run(
        test_v2_id: params[:id], required_implementation_date: release_params[:required_implementation_date]
      )

      if outcome.valid?
        render(json: {message: "Successfully released test_v2 (#{params[:id]}) to GA"}, status: 200)
      else
        render(json: {message: outcome.errors.full_messages.to_sentence}, status: 400)
      end
    end

    # POST /inside/test_v2s/promotions
    def refresh_promotion_queues
      CompanyTests::RefreshPromotionQueuesJob.perform_async(params[:company_ids] || [])

      render(json: {message: "Successfully started job to refresh promotion queues"}, status: 200)
    end

    private

    def create_new_versions_params
      params.permit(
        :old_test_v2_id,
        :change_description,
        new_test_v2s_data: [
          :additional_info,
          {assertion_data: {}},
          :assertion_key,
          {condition_data: {}},
          :condition_key,
          :description,
          :detailed_remediation_steps,
          :failure_message,
          :pass_message,
          :feature_flag,
          :helpful_resources,
          :key,
          :recommended_action,
          :required_implementation_date,
          :resource_category,
          :test_domain,
          :test_function,
          :test_type,
          :title,
          :vendor_id
        ]
      )
    end

    def bulk_test_v2_params
      params.permit(
        test_v2s: [
          :id,
          {assertion_data: {}},
          :assertion_key,
          {condition_data: {}},
          :condition_key,
          :description,
          :detailed_remediation_steps,
          :additional_info,
          :failure_message,
          :pass_message,
          :feature_flag,
          :key,
          :recommended_action,
          :helpful_resources,
          :resource_category,
          :test_domain,
          :test_function,
          :test_type,
          :title,
          :vendor_id,
          :vendor_slug,
          :required_implementation_date
        ]
      )
    end

    def test_v2_params
      params.permit(
        {assertion_data: {}},
        :assertion_key,
        {condition_data: {}},
        :condition_key,
        :description,
        :detailed_remediation_steps,
        :additional_info,
        :failure_message,
        :pass_message,
        :feature_flag,
        :key,
        :recommended_action,
        :helpful_resources,
        :resource_category,
        :test_domain,
        :test_function,
        :test_type,
        :title,
        :vendor_id,
        :vendor_slug,
        :change_description,
        :required_implementation_date
      )
    end

    def promotion_params
      params.permit(:company_id)
    end

    def release_params
      params.permit(:required_implementation_date)
    end
  end
end
