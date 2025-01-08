# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include GlobalAuthHelper
  include HttpAuthConcern

  before_action :set_sentry_context
  before_action :set_dd_rum_urls

  rescue_from GlobalAuth::UnauthorizedError, with: :render_unauthorized

  helper_method :custom_header_tags

  def render_error(e, status)
    render(json: {errors: e}, status: status)
  end

  def decode_token
    header = request.headers["Authorization"]
    token = header.split(" ").last if header

    begin
      JsonWebToken.decode(token)
    rescue JWT::DecodeError
      nil
    end
  end

  def render_unauthorized
    sign_out_user
    render_error("Unauthorized", 401)
  end

  def append_info_to_payload(payload)
    super
    payload[:level] = if payload[:status] == 200
      "INFO"
    elsif payload[:status] == 302
      "WARN"
    else
      "ERROR"
    end
  end

  private

  def set_sentry_context
    Sentry.set_extras(params: params.to_unsafe_h, url: request.url)
  end

  def set_dd_rum_urls
    app_host = Rails.configuration.application_host

    if Rails.configuration.is_trust_center
      add_dd_rum_url(host: app_host, regexp: true)
    else
      add_dd_rum_url(host: app_host)
    end
  end

  def add_dd_rum_url(host:, scheme: request.scheme, regexp: false)
    @dd_rum_urls ||= []

    @dd_rum_urls << if regexp
      Regexp.new("#{scheme}://.*#{host.gsub(".", "\\.")}")
    else
      "#{scheme}://#{host}"
    end
  end

  def custom_header_tags
    []
  end
end

# Allows for overriding of feature flagging for Cypress.
# https://simonecarletti.com/blog/2011/04/understanding-ruby-and-rails-lazy-load-hooks/
#
# Also used for loading hooks to tweak features in sandbox mode.
ActiveSupport.run_load_hooks(:application_controller)
