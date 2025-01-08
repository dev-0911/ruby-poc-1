# frozen_string_literal: true

class TrustCenterController < ApplicationController
  http_basic_authenticate_with(
    name: Rails.configuration.basic_auth_internal_username,
    password: Rails.configuration.basic_auth_internal_password,
    if: -> { Rails.configuration.enable_trust_center_basic_auth }
  )

  skip_before_action :verify_authenticity_token
  before_action :redirect_unless_html, only: :main

  def main
    if trust_center_slug.nil? || trust_center_version&.last_published_at.nil?
      return redirect_to(not_found_url)
    end

    trust_center_data = trust_center_version.data

    trust_center_styles = trust_center_data["trust_center_settings"].slice(
      "trust_center_id",
      "text_color",
      "background_color",
      "accent_color",
      "header",
      "sub_header"
    )
    trust_center_sections = trust_center_data["trust_center_sections"].map do |section|
      section["name"]
    end

    @company = trust_center_version.company
    @custom_css_url = AttachedTrustCenterAsset.find_by(
      id: trust_center_data["trust_center_settings"]["custom_css_file_id"]
    )&.blob_url

    @trust_center_data = {
      **trust_center_styles,
      sections: trust_center_sections,
      trust_center_slug: trust_center_slug,
      title: trust_center_data["trust_center_settings"]["site_title"] || @company.name,
      custom_css: trust_center_data["trust_center_settings"]["custom_css"]
    }

    @html_snapshot = nil
    if FeatureFlag.instance.enabled_for_company?(FeatureFlag::TRUST_CENTER_SPEEDUP, @company) && !params.key?(:disable_preloading)
      @html_snapshot = trust_center_version.trust_center_snapshots.last&.html
    end

    @prerendered = @html_snapshot.present?

    render :main
  rescue NoMethodError
    redirect_to not_found_url
  end

  alias_method :faqs, :main
  alias_method :compliance, :main
  alias_method :subprocessors, :main
  alias_method :resources_details, :main

  def resources
    if show_nda?
      return redirect_to_acknowledge_nda
    end

    trust_center_version = TrustCenterVersion
      .select("trust_center_versions.data, trust_centers.last_published_at, trust_centers.id")
      .joins(trust_center: :trust_center_requests)
      .where(
        trust_center_requests: {id: params[:trust_center_request_id]}
      )
      .order("trust_center_versions.created_at DESC")
      .first

    if trust_center_version&.last_published_at.present?
      trust_center_data = trust_center_version.data
      @trust_center_styles = trust_center_data["trust_center_settings"].slice(
        "text_color",
        "background_color",
        "accent_color"
      )
      logo_id = trust_center_data.dig("trust_center_settings", "logo_id")
      @company_logo_url = AttachedTrustCenterAsset.find_by(id: logo_id)&.blob_url if logo_id.present?
    else
      url = Company.find_by(id: trust_center_version.data["company_id"]).domain
      uri = URI.parse(url)

      if !uri.host
        redirect_to "https://secureframe.com"
      end

      if !uri.scheme
        redirect_to "https://#{url}"
      elsif %w[http https].include?(uri.scheme)
        redirect_to url
      else
        redirect_to "https://secureframe.com"
      end
    end
  end

  def acknowledge_nda
    if trust_center_version&.last_published_at.present?

      trust_center_data = trust_center_version.data
      logo_id = trust_center_data.dig("trust_center_settings", "logo_id")

      company_logo_url = AttachedTrustCenterAsset.find_by(id: logo_id)&.blob_url if logo_id.present?

      trust_center_styles = if trust_center_data["trust_center_theme"]
        trust_center_data["trust_center_theme"].slice(
          "on_surface_color",
          "surface_color",
          "primary_color",
          "on_primary_color"
        )
      else
        {
          on_surface_color: "#141312",
          surface_color: "#F3F9FE",
          primary_color: "#1061C4",
          on_primary_color: "#FFFFFF"
        }
      end

      @trust_center_data = {
        **trust_center_styles,
        logo_url: company_logo_url
      }
    end
  end

  def download_resources
    if trust_center_request.nil?
      return head 404, content_type: "text/html"
    end
    export = Exports::TrustCenterRequestResources.new(trust_center_request.id)
    tempfile = export.tempfile
    zip_data = File.read(tempfile.path)
    send_data(zip_data, type: "application/zip", filename: export.filename)
    trust_center_request.update(downloaded_at: Time.current)
  end

  def custom_header_tags
    favicon = nil

    if trust_center_slug.present?
      trust_center_settings = TrustCenterSettings.find_by(page_url: trust_center_slug)
      favicon = trust_center_settings&.favicon
    elsif params.key?(:trust_center_request_id)
      trust_center_request = TrustCenterRequest.find_by(id: params[:trust_center_request_id])
      favicon = AttachedTrustCenterAsset.find_by(
        trust_center_id: trust_center_request&.trust_center_id,
        discarded_at: nil,
        asset_type: AttachedTrustCenterAsset::FAVICON
      )
    end

    return [] if favicon.nil?
    [
      {
        tag: "link",
        attributes: {
          rel: "icon",
          type: favicon.blob.content_type,
          href: service_url(favicon.blob)
        }
      }
    ]
  end

  private def redirect_to_acknowledge_nda
    trust_center_settings = TrustCenterSettings.joins(trust_center: [:trust_center_requests])
      .where(trust_center: {
        trust_center_requests: {
          id: params[:trust_center_request_id]
        }
      })
      .first
    redirect_to acknowledge_nda_path(trust_center_settings.page_url,
      trust_center_request_id: params[:trust_center_request_id])
  end

  private def show_nda?
    trust_center_request&.nda_required?
  end

  private def trust_center_request
    @trust_center_request ||= TrustCenterRequest.find_by(id: params[:trust_center_request_id])
  end

  private def trust_center_version
    @trust_center_version ||= TrustCenterVersion
      .select("trust_center_versions.id, trust_center_versions.data, trust_centers.last_published_at, trust_center_versions.company_id")
      .joins(trust_center: :trust_center_settings)
      .where(trust_center_settings: {page_url: trust_center_slug})
      .order("trust_center_versions.created_at DESC")
      .first
  end

  private def service_url(blob)
    return "" if Rails.env.development?

    blob.service.url(
      blob.key,
      expires_in: 1.hour,
      disposition: :inline,
      filename: blob.filename,
      content_type: blob.content_type
    )
  end

  private def trust_center_slug
    return @trust_center_slug if @trust_center_slug
    if Rails.configuration.is_trust_center
      subdomain = request.subdomain
      domain = request.domain

      add_dd_rum_url(host: "#{subdomain}.#{domain}")

      if domain&.match?(/#{Rails.application.config.trust_center_domain}/)
        @trust_center_slug = subdomain
      else
        trust_center_settings = TrustCenterSettings.select(:page_url).find_by(cname_key: request.hostname)
        @trust_center_slug = trust_center_settings&.page_url
      end
    else
      @trust_center_slug = params[:trust_center_slug]
    end
  end

  private def not_found_url
    "https://secureframe.com/404"
  end

  private def redirect_unless_html
    unless request.format.html?
      client_ip = request.headers["X-Forwarded-For"] || request.remote_ip
      requested_format = request.format.to_sym.to_s
      Datadog::Tracing.active_span&.set_tags({
        "error.type": "trust_center.invalid_request_format",
        "error.message": "IP address: #{client_ip} sent #{requested_format} request for #{trust_center_slug}"
      })
      redirect_to trust_center_slug.nil? ? not_found_url : main_path(trust_center_slug, format: :html)
    end
  end
end
