class TestController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    test_response = Service.test_api_method
    render(json: {test: test_response}, status: :ok)
  end

  def health_check
    head(:no_content)
  end
end
