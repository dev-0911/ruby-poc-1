# Being extra careful here in the sense that this code should not initialized
# at all if this .is_sandbox setting isn't set.
#
# Should really only be loaded and configured in config/initializers/sandbox.rb
# when $IS_SANDBOX=true.
#
module SandboxMode
  extend ActiveSupport::Concern

  if Rails.configuration.is_sandbox
    included do
      before_action :keep_user_signed_in

      rescue_from ActiveRecord::StatementInvalid, with: :normalize_activerecord_readonly_errors
      rescue_from GraphQL::Backtrace::TracedError, with: :normalize_graphql_readonly_errors
    end

    private def current_user
      @current_user ||= current_company_user.user
    end

    private def current_company_user
      @current_company_user ||= CompanyUser.eager_load(:company, :user)
        .find(Rails.configuration.sandbox_company_user_id)
    end

    private def keep_user_signed_in
      set_auth_cookie(current_user)
    end

    # graphql wraps errors, so check against the unwrapped error
    private def normalize_graphql_readonly_errors(e)
      normalize_activerecord_readonly_errors(e.cause)
    end

    private def normalize_activerecord_readonly_errors(e)
      # Reraise if not a particular ActiveRecord::StatementInvalid error
      raise unless e.is_a?(ActiveRecord::StatementInvalid)
      raise unless e.message.start_with?("PG::InsufficientPrivilege: ERROR:  permission denied for")

      # if it is a proper error, raise the wrapped error to be ignored in Sentry
      raise Sandbox::ReadonlyError.new(e)
    end
  end
end
