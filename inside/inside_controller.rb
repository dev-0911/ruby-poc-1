# frozen_string_literal: true

module Inside
  class InsideController < BaseController
    # POST /inside/admin
    def create_admin
      company = Company.find(params[:company_id])
      user = User.find_by(email: params[:email]&.downcase)
      if user.nil?
        user = User.create!(
          first_name: params[:first_name],
          last_name: params[:last_name] || "",
          email: params[:email],
          password: params[:password] || SecureRandom.hex + "A$"
        )
      end

      access_role = company.super_admin_access_role
      if params[:access_role_id].present?
        access_role = company.access_roles.find(params[:access_role_id])
      end

      company_user = company.company_users.create(
        user_id: user.id,
        access_role: access_role,
        invited: true,
        employee_type: params[:employee_type]
      )

      unless company_user.valid?
        render(json: {message: e}, status: 400) && return
      end

      render(json: {message: "Secureframe admin created", data: {user: user}}, status: 200)
    rescue ActiveRecord::RecordNotFound
      render(json: {message: "Company not found for ID #{params[:company_id]}"}, status: 400) && return
    end

    # POST /inside/certifications
    def create_certification
      Vendor.find(params[:vendor_id])
      filename = URI.decode_www_form_component(params[:file_url].split("/")[-1])
      s3 = ::Aws::S3::Client.new(
        access_key_id: Rails.application.config.aws_access_key_id,
        secret_access_key: Rails.application.config.aws_secret_access_key,
        region: "us-west-2"
      )
      file_contents = s3.get_object(bucket: Rails.application.config.aws_inside_api_bucket, key: filename)
      tempfile = Tempfile.new
      tempfile.binmode
      tempfile.write(file_contents.body.read)
      file = ActionDispatch::Http::UploadedFile.new({
        filename: filename,
        type: file_contents.content_type,
        tempfile: tempfile
      })
      outcome = Certifications::Create.run(certification_params: certification_params.to_h.merge(files: [file]))
      if outcome.valid?
        render(json: {message: "Successfully created certification"}, status: 200)
      else
        error = "Failed to create certification. Error: #{outcome.errors.full_messages.join(", ")}"
        Rails.logger.error(error)
        render(json: {message: e}, status: 400) && return
      end
    rescue ActiveRecord::RecordNotFound
      render(json: {message: "Vendor not found for ID #{params[:vendor_id]}"}, status: 400) && return
    end

    # POST /inside/companies
    def create_company
      outcome = ::Companies::Create.run(company_params: company_creation_params.to_h)
      if outcome.valid?
        render(json: {message: "Successfully created company"}, status: 200)
      else
        error = "Failed to create company. Error: #{outcome.errors.full_messages.join(", ")}"
        Rails.logger.error(error)
        render(json: {message: error}, status: 400)
      end
    end

    # POST /inside/companies/:id/allotted_frameworks/increment
    def allotted_frameworks_increment
      company = Company.find_by(id: params[:id])
      return render(json: {error: "Company not found"}, status: 404) if company.blank?

      company.company_settings.increment!(:allotted_frameworks)
      render(json: {message: "Successfully incremented allotted_frameworks"}, status: 200)
    rescue => e
      render(json: {message: e}, status: 400)
    end

    # POST /inside/companies/:id/allotted_frameworks/decrement
    def allotted_frameworks_decrement
      company = Company.find_by(id: params[:id])
      return render(json: {error: "Company not found"}, status: 404) if company.blank?

      company_settings = company.company_settings
      if company_settings.allotted_frameworks > 0
        company_settings.decrement!(:allotted_frameworks)
        render(json: {message: "Successfully decremented allotted_frameworks"}, status: 200)
      else
        render(json: {error: "Cannot decrement below 0"}, status: 400)
      end
    rescue => e
      render(json: {message: e}, status: 400)
    end

    # POST /inside/companies/:id/allotted_workspaces/increment
    def allotted_workspaces_increment
      company = Company.find_by(id: params[:id])
      return render(json: {error: "Company not found"}, status: 404) if company.blank?

      company.company_settings.increment!(:allotted_workspaces)
      render(json: {message: "Successfully incremented allotted_workspaces"}, status: 200)
    rescue => e
      render(json: {message: e}, status: 400)
    end

    # POST /inside/companies/:id/allotted_workspaces/decrement
    def allotted_workspaces_decrement
      company = Company.find_by(id: params[:id])
      return render(json: {error: "Company not found"}, status: 404) if company.blank?

      company_settings = company.company_settings
      if company_settings.allotted_workspaces > 1
        company_settings.decrement!(:allotted_workspaces)
        render(json: {message: "Successfully decremented allotted_workspaces"}, status: 200)
      else
        render(json: {error: "Cannot decrement below 1"}, status: 400)
      end
    end

    # POST /inside/vendor_risks
    def create_vendor_risks
      company_id = params[:company_id]
      return render(json: {message: "Company ID is required"}, status: 400) if company_id.blank?

      company = Company.find_by(id: company_id)
      return render(json: {message: "Company not found for ID #{company_id}"}, status: 404) if company.blank?

      VendorRiskDetails::SetupVendorRiskModule.call(company: company)
      render(json: {message: "Successfully created vendor_risks for #{company.slug}"}, status: 200)
    rescue => e
      render(json: {message: e}, status: 400)
    end

    # POST /inside/trust_centers
    def create_trust_center
      company_id = params[:company_id]
      return render(json: {message: "Company ID is required"}, status: 400) if company_id.blank?

      company = Company.find_by(id: company_id)
      return render(json: {message: "Company not found for ID #{company_id}"}, status: 404) if company.blank?

      CreateTrustCenterJob.perform_async(company.id)
      render(json: {message: "Successfully created trust_center for #{company.slug}"}, status: 200)
    rescue => e
      render(json: {message: e}, status: 400)
    end

    # PATCH /inside/deactivate_company
    def deactivate_company
      company_id = deactivate_params[:company_id]
      billing_status = deactivate_params[:billing_status]

      if company_id.blank? || billing_status.blank?
        render(json: {message: "Required params not provided"}, status: 400)
        return
      end

      outcome = ::Companies::Deactivate.run(id: company_id, billing_status: billing_status)
      errors = outcome.errors.full_messages.to_sentence

      if errors.empty? && outcome.valid?
        render(json: {message: "Successfully deactivated company"}, status: 200)
      else
        render(json: {message: errors}, status: 400)
      end
    end

    # DELETE /inside/devices
    def delete_device
      device_id = params[:device_id]
      if device_id.nil?
        render(json: {message: "No device ID provided"}, status: 400) && return
      end

      device = Device.find(device_id)
      company_device_vendors = device.company_device_vendors.kept.unarchived.from_vendor_slug("secureframe_agent")
      if company_device_vendors.present?
        company_device_vendors.each do |company_device_vendor|
          client = Integrations::SecureframeAgent::Client.initialize_with_defaults({account_id: company_device_vendor.account_id})
          client.delete_device(company_device_vendor.third_party_id)
        end
      end

      device.destroy!
      render(json: {id: device_id, message: "Successfully deleted device from model"}, status: 200)
    rescue ActiveRecord::RecordNotFound
      render(json: {message: "Device not found for ID #{device_id}"}, status: 404)
    rescue ActiveRecord::RecordNotDestroyed => e
      render(json: {message: "Not Deleted: #{e.message}"}, status: 400)
    rescue => e
      Rails.logger.error("Error when deleting device: #{e.message}")
      render(json: {message: e.message}, status: 400)
    end

    # DELETE /inside/companies
    def delete_company
      company_id = company_deletion_params[:company_id]
      requester_email = company_deletion_params[:requester_email]

      if company_id.blank? || requester_email.blank?
        render(json: {message: "Required values not provided"}, status: 400) && return
      end

      secureframe = Company.find_by(slug: "secureframe")
      requester = secureframe.find_user_by_email(requester_email)

      if requester.nil?
        generate_response(
          message: "Requester email not found in Secureframe. Please specify a valid requester email.",
          status: 404,
          data: {requester_email: requester_email}
        ) && return
      end

      unless Company.exists?(company_id)
        generate_response(
          message: "Company not found.",
          status: 404,
          data: {company_id: company_id}
        ) && return
      end

      BulkJobs::Create.run(
        params: {
          action_type: BulkJob::DELETE_COMPANY,
          data: {company_to_delete: company_id},
          company_id: requester.company_id,
          requested_by_id: requester.id
        }
      )
      generate_response(
        message: "Successfully started company deletion job",
        status: 200
      ) && return
    end

    # PATCH /inside/reactivate_company
    def reactivate_company
      company_id = params[:company_id]
      if company_id.blank?
        render(json: {message: "Required params not provided"}, status: 400)
        return
      end

      outcome = ::Companies::Reactivate.run(id: company_id)
      errors = outcome.errors.full_messages.to_sentence

      if errors.empty?
        render(json: {message: "Company successfully reactivated"}, status: 200)
      else
        render(json: {message: errors}, status: 400)
      end
    end

    # POST /inside/password_reset_email
    def send_password_reset_email
      if params[:user_id].present?
        user = User.find_by(id: params[:user_id])
      elsif params[:email].present?
        user = User.find_by(email: params[:email].downcase)
      else
        render(json: {message: "user_id or email is required"}, status: 400) && return
      end

      if user.blank?
        render(json: {message: "User doesn't exist"}, status: 400) && return
      end

      # TODO: handle multiple companies per user
      user.company_users.first&.update(invited: true)
      user.send_reset_password_instructions
      render(json: {message: "Password reset instructions sent"}, status: 200)
    end

    # POST /inside/unlock_user
    def unlock_user
      if params[:user_id].present?
        user = User.find_by(id: params[:user_id])
      elsif params[:email].present?
        user = User.find_by(email: params[:email].downcase)
      else
        render(json: {message: "user_id or email is required"}, status: 400) && return
      end

      if user.blank?
        render(json: {message: "User doesn't exist"}, status: 404) && return
      end

      user.update_column(:locked_at, nil)
      render(json: {message: "Unlocked User"}, status: 200)
    end

    # PATCH /inside/employees
    def update_bulk_employees
      unless params.key?("records")
        render(json: {message: "Please provide records"}, status: 400)
        return
      end
      error_occured = false
      params["records"].each do |employee|
        # If access role is passed in as nil, set it equal to an empty string which will update it to nil in Update call
        # If access role is not passed in, or it is given a value, we can just pass it into update normally
        access_role_id =
          if employee.key?(:access_role_id) && employee[:access_role_id].nil?
            ""
          else
            employee[:access_role_id]
          end
        company_user = CompanyUser.find(employee[:id])
        begin
          result = Employees::Update.run({
            company_user: company_user,
            employee_params: {
              email: employee[:email],
              first_name: employee[:first_name],
              last_name: employee[:last_name],
              access_role_id: access_role_id,
              employee_type: employee[:employee_type],
              invited: employee[:invited]
            }
          })
        rescue ArgumentError
          error_occured = true
        end
        error_occured ||= !result.valid?
      end

      if error_occured
        render(json: {message: "Employee did not update"}, status: 400)
      else
        render(json: {message: "Employees successfully updated"}, status: 200)
      end
    end

    # DELETE /inside/company_vendors/:id
    def delete_company_vendor
      company_vendor_id = params[:id]
      company_vendor = CompanyVendor.find(company_vendor_id)
      company_vendor.destroy!
      render(json: {id: company_vendor_id, message: "Successfully deleted company vendor"}, status: 200) && return
    rescue ActiveRecord::RecordNotFound
      render(json: {message: "CompanyVendor not found for ID #{params[:company_vendor_id]}"}, status: 404) && return
    rescue ActiveRecord::RecordNotDestroyed => e
      render(json: {message: "Not Deleted: #{e.message}"}, status: 400) && return
    rescue ActiveRecord::RecordInvalid, ActiveInteraction::Error, ArgumentError => e
      render(json: {message: e.message}, status: 400) && return
    end

    # POST /inside/company_vendors/:id/archive
    def archive_company_vendor
      company_vendor_id = params[:id]
      company_vendor = CompanyVendor.find(company_vendor_id)
      company_vendor.archive!
      render(json: {id: company_vendor_id, message: "Successfully archived company vendor"}, status: 200) && return
    rescue ActiveRecord::RecordNotFound
      render(json: {message: "CompanyVendor not found for ID #{params[:company_vendor_id]}"}, status: 404) && return
    rescue Archive::Errors::RecordNotArchived => e
      render(json: {message: "Not Archived: #{e.message}"}, status: 400) && return
    rescue ActiveRecord::RecordInvalid, ActiveInteraction::Error, ArgumentError => e
      render(json: {message: e.message}, status: 400) && return
    end

    def reset_trainings
      outcome = ::Companies::ResetTrainings.run(
        company_id: params[:company_id],
        training_slug: params[:training_slug],
        since_date: CompanyUserTraining::EXPIRATION_PERIOD.ago.beginning_of_day
      )
      if outcome.valid?
        render(json: {message: "Trainings reset"}, status: 200)
      else
        render(json: {message: outcome.errors.full_messages.to_sentence}, status: 400)
      end
    end

    def trigger_email_notifications_job
      Notifications::Scheduler.perform_async
      render(json: {message: "Email notifications job triggered"}, status: 200)
    end

    # POST inside/send_magic_link_email
    def send_magic_link_email
      outcome = ::Workos::SendMagicLinkEmail.run(email: params[:email])
      if outcome.valid?
        render(json: {message: outcome.result}, status: 200)
      else
        render(json: {message: outcome.errors.full_messages.to_sentence}, status: 400)
      end
    end

    # POST /inside/global_signin
    def global_signin
      email = params[:email]
      password = params[:password]
      outcome = Users::SignIn.run({user_params: {email: email, password: password}})
      if outcome.valid?
        region_data = PeerRegion.find(UserRegionLocator.find_by_email(email).region)
        render(json: {
          user: outcome.result,
          region: {
            code: region_data.region,
            hostname: region_data.hostname,
            baseUrl: region_data.base_url
          }
        }, status: 200)
      else
        render(json: {user: nil, errors: outcome.errors.full_messages}, status: 200)
      end
    end

    # POST /inside/google_oauth_sign_in
    def google_oauth_sign_in
      permitted_params = params.permit(
        :primary_email,
        :third_party_id,
        :google_workspace_customer_id,
        :all_scopes_present
      )

      permitted_params[:auth_hash] = params[:auth_hash].permit!

      outcome = ::Integrations::Google::GoogleWorkspace::PerformGoogleLogin.run(
        primary_email: permitted_params[:primary_email],
        third_party_id: permitted_params[:third_party_id],
        auth_hash: permitted_params[:auth_hash],
        google_workspace_customer_id: permitted_params[:google_workspace_customer_id],
        all_scopes_present: permitted_params[:all_scopes_present]
      )

      if outcome.valid?
        render(json: {
          user: outcome.result
        }, status: 200)
      else
        render(json: {user: nil, errors: outcome.errors.full_messages}, status: 200)
      end
    end

    # POST /inside/office_365_oauth_sign_in
    def office_365_oauth_sign_in
      permitted_params = params.permit(
        :primary_email,
        :third_party_id
      )

      outcome = ::Integrations::Microsoft::Office365::PerformLogin.run(
        primary_email: permitted_params[:primary_email],
        third_party_id: permitted_params[:third_party_id]
      )

      if outcome.valid?
        render(json: {
          user: outcome.result
        }, status: 200)
      else
        render(json: {user: nil, errors: outcome.errors.full_messages}, status: 200)
      end
    end

    def get_workos_authorization_url
      outcome = ::Workos::GetAuthorizationUrl.run(email: params[:email], landing_page_url: params[:landing_page_url])
      if outcome.valid?
        render(json: {message: "success", url: outcome.result}, status: 200)
      else
        render(json: {message: outcome.errors.full_messages.to_sentence}, status: 400)
      end
    end

    private

    def generate_response(message:, status:, data: {})
      render(json: {message: message, **data}, status: status)
    end

    def certification_params
      params.except(:file_url, :inside).permit(
        :vendor_id,
        :has_nda,
        :certification_type
      )
    end

    def company_creation_params
      params.permit(
        :name,
        :legal_name,
        :domain,
        :description,
        :address_line_1,
        :address_line_2,
        :city,
        :state,
        :zip_code,
        :country_code,
        :phone_number,
        :privacy_policy_url,
        :terms_of_service_url,
        :customer_facing_url,
        :customer_contact_url,
        :entity_type,
        :founded_year,
        :ein,
        :state_of_incorporation,
        :security_email,
        :parent_company_id
      )
    end

    def company_deletion_params
      params.permit(:company_id, :requester_email)
    end

    def deactivate_params
      params.permit(
        :company_id,
        :billing_status
      )
    end
  end
end
