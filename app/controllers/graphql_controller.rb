# frozen_string_literal: true

class GraphqlController < ApplicationController
  include RefreshCookie

  InvalidVariables = Class.new(StandardError)

  rate_limit to: 60, within: 1.minute, only: :execute, with: -> {
    response.set_header("Retry-After", "60")
    head :too_many_requests
  }
  before_action :require_json

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
  rescue InvalidVariables => e
    render json: { errors: [ { message: e.message } ] }, status: :bad_request
  rescue StandardError => e
    raise e unless Rails.env.development?
    handle_error_in_development(e)
  end

  private

  # Form-encoded bodies are simple cross-site requests; JSON forces a CORS preflight.
  def require_json
    return if request.media_type == "application/json"

    render json: { errors: [ { message: "Content-Type must be application/json" } ] }, status: :unsupported_media_type
  end

  def prepare_variables(variables_param)
    case variables_param
    when String
      variables_param.present? ? parse_variables(variables_param) : {}
    when Hash
      variables_param
    when ActionController::Parameters
      variables_param.to_unsafe_hash # GraphQL-Ruby will validate name and type of incoming variables.
    when nil
      {}
    else
      raise InvalidVariables, "variables must be a JSON object"
    end
  end

  def parse_variables(json)
    parsed = JSON.parse(json)
    raise InvalidVariables, "variables must be a JSON object" unless parsed.nil? || parsed.is_a?(Hash)

    parsed || {}
  rescue JSON::ParserError
    raise InvalidVariables, "variables is not valid JSON"
  end

  def handle_error_in_development(e)
    logger.error e.message
    logger.error e.backtrace.join("\n")

    render json: { errors: [ { message: e.message, backtrace: e.backtrace } ], data: {} }, status: 500
  end

  def current_user
    token = request.authorization.to_s[/\ABearer (.+)\z/i, 1]
    return unless token

    user_id = AuthToken.decode(token)
    User.find_by(id: user_id) if user_id
  end
end
