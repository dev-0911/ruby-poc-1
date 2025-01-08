# frozen_string_literal: true

module Inside
  class AiController < BaseController
    # POST /inside/generate_ai_test_remediation
    def generate_test_remediation
      company_test = CompanyTest.find(generate_test_remediation_params[:company_test_id])
      test_remediation = TestRemediation.find(generate_test_remediation_params[:test_remediation_id])
      prompt = generate_test_remediation_params[:prompt]
      temperature = generate_test_remediation_params[:temperature]

      formatted_prompt = TestRemediationPrompt.new(prompt).format_prompt(test_remediation, company_test)

      response = SecurityQuestionnaireApi::CreateComplyAiTestRemediation.run(
        prompt: formatted_prompt,
        temperature: temperature
      )
      if response.valid?
        render(json: {response: response}, status: 200)
      else
        render(json: {message: outcome.errors.full_messages.join(", ")}, status: 400)
      end
    rescue ActiveRecord::RecordNotFound => e
      render(
        json: {
          message: "Record(s) not found: #{e.message}"
        },
        status: 404
      ) && return
    rescue ActiveRecord::RecordInvalid, ActiveInteraction::Error, StandardError => e
      generate_response(message: e.message, status: 400) && return
    end

    # POST /inside/update_ai_test_remediation
    def update_test_remediation
      test_remediation_id = update_test_remediation_params[:test_remediation_id]
      prompt = update_test_remediation_params[:prompt]
      temperature = update_test_remediation_params[:temperature]
      enabled = update_test_remediation_params[:enabled]

      outcome = TestRemediations::Update.run(
        test_remediation_id: test_remediation_id,
        attributes: {
          prompt: prompt,
          temperature: temperature,
          enabled: enabled
        }
      )
      if outcome.valid?
        render(json: {test_remediation: outcome.result}, status: 200)
      else
        render(json: {message: outcome.errors.full_messages.join(", ")}, status: 400)
      end
    rescue ActiveRecord::RecordInvalid, ActiveInteraction::Error, StandardError => e
      generate_response(message: e.message, status: 400) && return
    end

    private

    def generate_response(message:, status:, data: {})
      render(json: {message: message, **data}, status: status)
    end

    def generate_test_remediation_params
      params.permit(
        :company_test_id,
        :test_remediation_id,
        :prompt,
        :temperature
      )
    end

    def update_test_remediation_params
      params.permit(
        :test_remediation_id,
        :prompt,
        :temperature,
        :enabled
      )
    end
  end
end
