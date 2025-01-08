# frozen_string_literal: true

module SecurityQuestionnaires
  class SecurityQuestionnairesController < BaseController
    before_action :custom_authenticate, except: [:download_attachments]

    # GET /security_questionnaires/companies/:company_id
    # Returns the company's details
    def get_company_details
      company = Company.find(params[:company_id])
      details = {
        name: company.name,
        id: company.id,
        domain: company.domain,
        description: company.description,
        phone_number: company.phone_number,
        security_email: company.security_email,
        customer_facing_url: company.customer_facing_url,
        founded_year: company.founded_year,
        state_of_incorporation: company.state_of_incorporation,
        country_of_incorporation: company.country_of_incorporation
      }

      render(json: details, status: 200)
    rescue ActiveRecord::RecordNotFound
      render(json: {message: "Company not found for ID #{params[:company_id]}"}, status: 404)
    rescue ActiveRecord::RecordInvalid, StandardError => e
      Rails.logger.error(e.message)
      generate_response(message: e.message, status: 400)
    end

    # GET /security_questionnaires/companies/:company_id/policies
    def get_company_policies
      company = Company.find(params[:company_id])
      policies = company.policies.published
      render(json: policies, status: 200) && return
    rescue ActiveRecord::RecordNotFound
      render(json: {message: "Company not found for ID #{params[:company_id]}"}, status: 404) && return
    rescue ActiveRecord::RecordInvalid, StandardError => e
      Rails.logger.error(e.message)
      generate_response(message: e.message, status: 400) && return
    end

    # GET /security_questionnaires/companies/:company_id/controls
    # Returns all control_v2s and company_control_v2s for a company
    def get_company_controls
      company = Company.find(params[:company_id])
      payload = company.company_control_v2s.includes(:control_v2).map do |company_control_v2|
        counter_data = company_control_v2.counter_data
        company_control_v2_json = company_control_v2.as_json(
          except: [:passing_test_count, :at_risk_test_count, :failing_test_count, :disabled_test_count]
        )
        counter_data_json = {
          passing_test_count: counter_data.passing_test_count,
          at_risk_test_count: counter_data.at_risk_test_count,
          failing_test_count: counter_data.failing_test_count,
          disabled_test_count: counter_data.disabled_test_count
        }

        {
          control: company_control_v2.control_v2,
          company_control: company_control_v2_json.merge(counter_data_json)
        }
      end

      render(json: payload, status: 200)
    rescue ActiveRecord::RecordNotFound
      render(json: {message: "Company not found for ID #{params[:company_id]}"}, status: 404)
    rescue ActiveRecord::RecordInvalid, StandardError => e
      Rails.logger.error(e.message)
      generate_response(message: e.message, status: 400)
    end

    # GET /security_questionnaires/companies/:company_id/tests
    def get_company_tests
      company = Company.find(params[:company_id])
      payload = company.company_tests.includes(:test_v2, :assertion_results).map do |company_test|
        assertion_results = AssertionResultRepository.assertion_results_for_company_test(company_test)
        {
          test: company_test.test_v2,
          company_test: company_test,
          assertion_results: assertion_results
        }
      end
      render(json: payload, status: 200)
    rescue ActiveRecord::RecordNotFound
      render(json: {message: "Company not found for ID #{params[:company_id]}"}, status: 404)
    rescue ActiveRecord::RecordInvalid, StandardError => e
      Rails.logger.error(e.message)
      generate_response(message: e.message, status: 400)
    end

    # GET /security_questionnaires/companies/:company_id/knowledge_base_question_answers
    def get_company_question_answers
      company = Company.find(params[:company_id])
      payload = company.knowledge_base_questions.map do |question|
        {
          question: question,
          answers: question.knowledge_base_answers.map do |answer|
            {
              id: answer.id,
              content: answer.content,
              answer_type: answer.type,
              primary_answer: answer.primary_answer
            }
          end
        }
      end
      render(json: payload, status: 200)
    rescue ActiveRecord::RecordNotFound
      render(json: {message: "Company not found for ID #{params[:company_id]}"}, status: 404)
    rescue ActiveRecord::RecordInvalid, StandardError => e
      Rails.logger.error(e.message)
      generate_response(message: e.message, status: 400)
    end

    # POST /inside/companies/:company_id/security_questionnaires/:security_questionnaire_id
    # Security questionnaire Haystack prediction result processing
    def process_company_security_questionnaire_response
      company = Company.find(prediction_result_params[:company_id])
      security_questionnaire =
        company.security_questionnaires.kept.find_by_id(prediction_result_params[:security_questionnaire_id])

      raise ActiveRecord::RecordNotFound unless security_questionnaire

      results = prediction_result_params[:sheets].to_h

      if security_questionnaire && results
        prediction_result_doc = security_questionnaire.prediction_result_documents.create!(prediction_data: results)

        ProcessSecurityQuestionnairePredictionResultsJob.perform_async(prediction_result_doc.id)

        render(json: {}, status: 200)
      else
        render(json: {}, status: 500)
      end
    rescue ActiveRecord::RecordNotFound
      render(
        json: {
          message: "Record(s) not found for company id #{prediction_result_params[:company_id]} " \
            "and/or #{prediction_result_params[:security_questionnaire_id]}"
        },
        status: 404
      ) && return
    rescue ActiveRecord::RecordInvalid, StandardError => e
      Rails.logger.error(e.message)
      generate_response(message: e.message, status: 400) && return
    end

    # POST /companies/:company_id/security_questionnaires/:security_questionnaire_id/seed
    def process_company_security_questionnaire_seed_response
      company = Company.find(seed_result_params[:company_id])
      security_questionnaire =
        company&.security_questionnaires&.kept&.find_by_id(seed_result_params[:security_questionnaire_id])

      raise ActiveRecord::RecordNotFound unless security_questionnaire

      if seed_result_params[:status] == "ok"
        security_questionnaire.complete_file_seeded!
        render(json: {}, status: 200)
      else
        render(json: {}, status: 500)
      end
    rescue ActiveRecord::RecordNotFound
      render(
        json: {
          message: "Record(s) not found for company id #{seed_result_params[:company_id]} " \
          "and/or #{seed_result_params[:security_questionnaire_id]}"
        },
        status: 404
      ) && return
    rescue ActiveRecord::RecordInvalid, StandardError => e
      Rails.logger.error(e.message)
      generate_response(message: e.message, status: 400) && return
    end

    def process_test_remediation_response
      company = Company.find(test_remediation_params[:company_id])
      company_test_remediation_chat =
        company.company_test_remediation_chats.find_by(id: test_remediation_params[:company_test_remediation_chat_id])

      raise ActiveRecord::RecordNotFound unless company_test_remediation_chat

      if test_remediation_params[:status] != "ok"
        Sentry.capture_message(
          "#process_test_remediation_response: status is not ok",
          extra: {test_remediation_params: test_remediation_params}
        )
        company_test_remediation_chat.create_error_message
        render(json: {message: test_remediation_params[:error]}, status: 500) && return
      end

      response = CompanyTestRemediationChatMessages::Create.run(
        company_user: nil,
        company_test_remediation_chat_id: company_test_remediation_chat.id,
        message: test_remediation_params[:response],
        from_ai: true
      )
      message = response.result

      render(json: {company_test_remediation_chat_message: message}, status: 200)
    rescue ActiveRecord::RecordNotFound
      render(
        json: {
          message: "Record(s) not found for company id #{test_remediation_params[:company_id]} " \
          "and/or #{test_remediation_params[:security_questionnaire_id]}"
        },
        status: 404
      ) && return
    rescue ActiveRecord::RecordInvalid, ActiveInteraction::Error, StandardError => e
      Sentry.capture_message(
        "#process_test_remediation_response: #{e.message}",
        extra: {test_remediation_params: test_remediation_params}
      )
      company_test_remediation_chat.create_error_message
      generate_response(message: e.message, status: 400) && return
    end

    def process_question_remediation_response
      company = Company.find(question_remediation_params[:company_id])
      remediation_chat =
        company.remediation_chats.find_by(
          remediated_type: "SecurityQuestionnaireQuestion",
          remediated_id: question_remediation_params[:question_id]
        )

      raise ActiveRecord::RecordNotFound unless remediation_chat

      if question_remediation_params[:status] != "ok"
        Sentry.capture_message(
          "#process_question_remediation_response: status is not ok",
          extra: {question_remediation_params: question_remediation_params}
        )
        remediation_chat.create_error_message
        render(json: {message: question_remediation_params[:error]}, status: 500) && return
      end

      response = RemediationChatMessages::Create.run(
        company_user: nil,
        remediation_chat_id: remediation_chat.id,
        content: question_remediation_params[:response],
        from_ai: true
      )
      message = response.result

      render(json: {remediation_chat_message: message}, status: 200)
    rescue ActiveRecord::RecordNotFound
      render(
        json: {
          message: "Record(s) not found for company id #{question_remediation_params[:company_id]} " \
          "and question id #{question_remediation_params[:question_id]}"
        },
        status: 404
      ) && return
    rescue ActiveRecord::RecordInvalid, ActiveInteraction::Error, StandardError => e
      Sentry.capture_message(
        "#process_question_remediation_response: #{e.message}",
        extra: {question_remediation_params: question_remediation_params}
      )
      remediation_chat.create_error_message
      generate_response(message: e.message, status: 400) && return
    end

    def download_attachments
      security_questionnaire = SecurityQuestionnaire.find_by(id: params[:id])
      prediction_result = security_questionnaire.prediction_result_documents.last

      return if prediction_result.nil?

      files = security_questionnaire.security_questionnaire_questions.map do |question|
        question.attached_evidences.map { |attached| attached.evidence.document.file }
      end

      questionids = security_questionnaire.security_questionnaire_questions.map(&:id)

      policy_ids = AttachedPolicy.where(attached_to_id: questionids).pluck(:policy_id)

      return if files.flatten.empty? && policy_ids.empty?

      files << prediction_result.document.file

      tempfile = Exports::SecurityQuestionnaireAttachments.new(files.flatten, policy_ids).zip
      zip_data = File.read(tempfile.path)
      send_data(zip_data, type: "application/zip", filename: prediction_result.document.file.blob.filename.to_s)
    end

    private

    def custom_authenticate
      authenticate_or_request_with_http_basic do |username, password|
        if username == Rails.application.config.security_questionnaires_data_access_key
          true
        else
          handle_unauthorized_error
          false
        end
      end
    end

    def handle_unauthorized_error
      Rails.logger.error("SQ Controller Auth error")
      SlackNotificationJob.perform_async(
        "security-q-notifications",
        ["SQ-API Rails controller auth error @security-questionnair-team"]
      )
    end

    def generate_response(message:, status:, data: {})
      render(json: {message: message, **data}, status: status)
    end

    def prediction_result_params
      params.permit(
        :security_questionnaire_id,
        :company_id,
        sheets: {}
      )
    end

    def seed_result_params
      params.permit(
        :security_questionnaire_id,
        :company_id,
        :status,
        :message
      )
    end

    def test_remediation_params
      params.permit(
        :company_id,
        :company_test_remediation_chat_id,
        :status,
        :response,
        :error
      )
    end

    def question_remediation_params
      params.permit(
        :company_id,
        :security_questionnaire_id,
        :question_id,
        :status,
        :response,
        :error
      )
    end
  end
end
