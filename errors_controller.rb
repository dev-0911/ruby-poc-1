# frozen_string_literal: true

class ErrorsController < ApplicationController
  protect_from_forgery with: :null_session

  def internal_server_error
    redirect_to(root_path(error: "Something went wrong"), formats: :html)
  end
end
