# frozen_string_literal: true

class Api::CompaniesController < Api::BaseController
  PERMISSION_REQUIRED = Permission::ACCOUNT_SETTINGS

  # TODO: Yard docs to come
  # GET /companies/{id}
  def show
    super
  end
end
