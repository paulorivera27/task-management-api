# frozen_string_literal: true

class GraphqlController < ApplicationController
  include RefreshCookie

  def execute
    variables = prepare_variables(params[:variables])
    query = params[:query]
    operation_name = params[:operationName]
    refresh_cookie_data = {}
    context = {
      current_user: current_user,
      refresh_cookie_data: refresh_cookie_data
    }
    result = TaskManagementApiSchema.execute(query, variables: variables, context: context, operation_name: operation_name)

    set_refresh_cookie(refresh_cookie_data) if refresh_cookie_data[:value]

    render json: result
  rescue StandardError => e
    raise e unless Rails.env.development?
    handle_error_in_development(e)
  end

  private

  # Handle variables in form data, JSON body, or a blank value
  def prepare_variables(variables_param)
    case variables_param
    when String
      if variables_param.present?
        JSON.parse(variables_param) || {}
      else
        {}
      end
    when Hash
      variables_param
    when ActionController::Parameters
      variables_param.to_unsafe_hash # GraphQL-Ruby will validate name and type of incoming variables.
    when nil
      {}
    else
      raise ArgumentError, "Unexpected parameter: #{variables_param}"
    end
  end

  def handle_error_in_development(e)
    logger.error e.message
    logger.error e.backtrace.join("\n")

    render json: { errors: [ { message: e.message, backtrace: e.backtrace } ], data: {} }, status: 500
  end

  def current_user
    token = request.headers["Authorization"]&.split(" ")&.last
    return unless token

    user_id = AuthToken.decode(token)
    User.find_by(id: user_id) if user_id
  end
end
