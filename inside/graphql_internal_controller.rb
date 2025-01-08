module Inside
  class GraphqlInternalController < BaseController
    include GraphqlHelper

    def execute
      variables = ensure_hash(params[:variables])
      query = params.require(:query)
      operation_name = infer_operation_name(query)

      # Before enabling mutations via this API, be sure to sort out how they'll be attributed in audit logs.
      # Currently, if enabled, changes will be attributed to a single system user.
      # If possible we should add an authentication solution to allow them to be attributed to the
      # actual user performing the action.
      result = if mutation?(query)
        GraphQL::ExecutionError.new("The API is not available for mutations")
      elsif Company.find_by(id: request.headers["contextCompanyId"]).nil?
        GraphQL::ExecutionError.new("Company not found")
      else
        SecureframeSchema.execute(
          query,
          variables: variables,
          context: graphql_execute_context,
          operation_name: operation_name
        )
      end

      render json: result.to_h
    end

    private

    def graphql_execute_context
      context_company_id = request.headers["contextCompanyId"]

      current_user = User.find_by(email: "engineering+retoolapp@secureframe.com")

      company = Company.find_by(id: context_company_id)

      current_company_user = CompanyUser.new(
        user: current_user,
        company: company,
        employee_type: "external",
        access_role: AccessRole.find_by(
          access_role_type: AccessRole::SUPER_ADMIN,
          company: company
        )
      )

      {
        current_user: current_user,
        current_company_user: current_company_user,
        current_ability: Ability.new(current_user, current_company_user)
      }
    end

    def mutation?(query)
      parsed_query = GraphQL.parse(query)
      parsed_query.definitions.any? do |definition|
        definition.is_a?(GraphQL::Language::Nodes::OperationDefinition) && definition.operation_type == "mutation"
      end
    end
  end
end
