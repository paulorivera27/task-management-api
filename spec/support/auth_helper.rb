# frozen_string_literal: true

module AuthHelper
  def auth_headers(user)
    token = AuthToken.encode(user.id)
    { "Authorization" => "Bearer #{token}" }
  end
end
