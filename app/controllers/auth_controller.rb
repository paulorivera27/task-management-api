# frozen_string_literal: true

class AuthController < ApplicationController
  include RefreshCookie

  # The frontend reads any non-2xx refresh as "logged out", so keep this well above normal reload rates.
  rate_limit to: 120, within: 1.minute, only: :refresh, with: -> {
    response.set_header("Retry-After", "60")
    head :too_many_requests
  }

  def refresh
    refresh_token = RefreshToken.find_by_raw_token(read_refresh_cookie)
    outcome, raw_token, new_token = refresh_token&.rotate!
    response.headers["Cache-Control"] = "no-store"

    case outcome
    when :rotated
      set_refresh_cookie(value: raw_token, expires: new_token.expires_at)
      expire_legacy_refresh_cookie
      render_session(refresh_token.user)
    when :grace
      # A retired sibling, or a replay past the sibling cap: tolerated for the grace window without a new cookie.
      render_session(refresh_token.user)
    else
      delete_refresh_cookie
      render json: { error: "Invalid or expired refresh token" }, status: :unauthorized
    end
  end

  def logout
    RefreshToken.find_by_raw_token(read_refresh_cookie)&.revoke_family!

    delete_refresh_cookie
    head :no_content
  end

  private

  def render_session(user)
    render json: { token: AuthToken.encode(user.id), user: { id: user.id, email: user.email } }
  end
end
