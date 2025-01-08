# frozen_string_literal: true

module Inside
  class CloudqueryTestController < BaseController
    rescue_from StandardError, with: :server_error

    # POST /inside/cloudquery_test/validate
    def validate_cloudquery_test
      company_id = params[:company_id]
      cloudquery_test_key = params[:cloudquery_test_key]
      begin
        company = Company.find(company_id)
      rescue ActiveRecord::RecordNotFound
        render(json: {message: "Company not found for ID #{company_id}"}, status: 404) && return
      end

      render(
        json: MaintenanceTask::ValidateCustomCloudTest.call(cloudquery_test_key, company),
        include: [:assertion_results]
      )
    end

    # POST /inside/cloudquery_test/run
    def run_cloudquery_test
      company_id = params[:company_id]
      cloudquery_test_key = params[:cloudquery_test_key]
      begin
        company = Company.find(company_id)
      rescue ActiveRecord::RecordNotFound
        render(json: {message: "Company not found for ID #{company_id}"}, status: 404) && return
      end

      cq_test = TestV2.find_by(key: cloudquery_test_key)
      company_test = cq_test.evaluate_for(company, validation_run: true)

      render(
        json: company_test,
        include: [:assertion_results]
      )
    end

    # POST /inside/cloudquery_test/validate/global
    def globally_validate_cloudquery_test
      cloudquery_test_key = params[:cloudquery_test_key]
      cloudsploit_test_key = get_predecessor_key(cloudquery_test_key)

      company_tests = CompanyTest.joins(:test_v2).where(test_v2s: {key: cloudsploit_test_key}, enabled: true)
      companies = company_tests.map { |ct| ct.company }

      validation_results = {}

      companies.each do |company|
        results = MaintenanceTask::ValidateCustomCloudTest.call(cloudquery_test_key, company)
        results["company_name"] = company.name
        validation_results[company.id] = results
      end

      render(
        json: validation_results
      )
    end

    # POST /inside/cloudquery_test/validate/bulk
    def bulk_validate_cloudquery_test
      cloudquery_test_key = params[:cloudquery_test_key]
      cloudsploit_test_key = get_predecessor_key(cloudquery_test_key)
      company_ids = params[:company_ids]

      company_tests = CompanyTest.joins(:test_v2).where(
        test_v2s: {key: cloudsploit_test_key},
        enabled: true
      )
      companies = company_tests.map { |ct| ct.company }.filter { |c| company_ids.include?(c.id) }

      validation_results = {}

      companies.each do |company|
        results = MaintenanceTask::ValidateCustomCloudTest.call(cloudquery_test_key, company)
        results["company_name"] = company.name
        validation_results[company.id] = results
      end

      render(
        json: validation_results
      )
    end

    # POST /inside/cloudquery_test/query/execute
    def execute_cloudquery_searchkick_query
      company_id = params[:company_id]
      query = params[:query]
      company = Company.find(company_id)

      query = JSON.parse(query.to_json, object_class: OpenStruct)
      model = query["model"].constantize

      filter = nil
      if model.respond_to?(:company_searchkick_filter)
        filter = model.company_searchkick_filter(company_id)
      end

      failing_search_results = SearchkickExecutor.call(nil, query, filter, nil, company)
      records_for_company = model.with_company_id(company_id)

      failing_model_records = records_for_company & convert_search_results(
        model,
        failing_search_results
      )
      passing_model_records = records_for_company - failing_model_records

      results = {
        failing_results: failing_model_records,
        passing_results: passing_model_records
      }
      render(json: results)
    end

    private def get_predecessor_key(cloudquery_test_key)
      old_test = TestV2.find_by(key: cloudquery_test_key).preceding_test_v2

      if old_test.nil?
        cloudquery_test_key[3..]
      else
        old_test.key
      end
    end

    private def server_error(error)
      render json: error.inspect, status: 400
    end

    private def convert_search_results(model, search_results)
      record_ids = search_results.map do |result|
        is_cloudquery_model?(model.name) ? result._cq_id : result.id
      end

      col_name = is_cloudquery_model?(model.name) ? "_cq_id" : model.primary_key.to_s

      model.where("#{col_name} IN (?)", record_ids)
    end

    private def is_cloudquery_model?(model_name)
      model_prefixes = ["Aws", "Azure", "Digitalocean", "Gcp"]
      model_prefixes.any? { |provider| model_name.starts_with?(provider) }
    end
  end
end
