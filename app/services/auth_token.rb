# frozen_string_literal: true

class AuthToken
  SECRET_KEY = Rails.application.secret_key_base
  EXPIRATION = 15.minutes.to_i

  def self.encode(user_id)
    payload = {
      user_id: user_id,
      exp: Time.now.to_i + EXPIRATION
    }
    JWT.encode(payload, SECRET_KEY, "HS256")
  end

  def self.decode(token)
    decoded = JWT.decode(token, SECRET_KEY, true, algorithm: "HS256")
    decoded.first["user_id"]
  rescue JWT::DecodeError, JWT::ExpiredSignature
    nil
  end
end
