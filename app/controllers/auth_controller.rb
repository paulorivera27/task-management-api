# frozen_string_literal: true

class AuthController < ApplicationController
  include RefreshCookie

  def refresh
    raw_token = read_refresh_cookie
    refresh_token = RefreshToken.find_by_raw_token(raw_token)

    if refresh_token
      new_access_token = AuthToken.encode(refresh_token.user_id)
      render json: { token: new_access_token, user: { id: refresh_token.user.id, email: refresh_token.user.email } }
    else
      delete_refresh_cookie
      render json: { error: "Invalid or expired refresh token" }, status: :unauthorized
    end
  end

  def logout
    raw_token = read_refresh_cookie
    refresh_token = RefreshToken.find_by_raw_token(raw_token)
    refresh_token&.revoke!

    delete_refresh_cookie
    head :no_content
  end
end
