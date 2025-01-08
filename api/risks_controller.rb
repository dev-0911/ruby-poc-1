# frozen_string_literal: true

class Api::RisksController < Api::BaseController
  PERMISSION_REQUIRED = Permission::RISK_MANAGEMENT

  # NOTE: this is currently only here as an example. Not available for API consumers yet.
  # POST /risks/{id}
  def create
    super
  end

  private def set_create_interaction_variables(valid_params:)
    variables = variables_for_create_interaction
    variables[:params] = valid_params.merge(company_id: @api_key.company_id)
    variables
  end
end
