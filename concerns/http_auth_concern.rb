# frozen_string_literal: true

module HttpAuthConcern
  extend ActiveSupport::Concern
  included do
    before_action :http_authenticate
  end
  def http_authenticate
    true
  end
end
