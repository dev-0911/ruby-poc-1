class AgentController < ApplicationController
  skip_before_action :verify_authenticity_token

  def download_debian_linux
    filename = package_client.get_filename("deb")
    send_data(package_client.get_file(params[:id], filename), filename: filename)
  end

  def download_osx
    filename = package_client.get_filename("dmg")
    send_data(package_client.get_file(params[:id], filename), filename: filename)
  end

  def download_windows
    filename = package_client.get_filename("msi")
    send_data(package_client.get_file(params[:id], filename), filename: filename)
  end

  private

  def package_client
    @package_client ||= Integrations::SecureframeAgent::PackageClient.new
  end
end
