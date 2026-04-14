# frozen_string_literal: true

module RefreshCookie
  extend ActiveSupport::Concern

  REFRESH_COOKIE_NAME = "refresh_token"

  private

  def set_refresh_cookie(data)
    response.set_cookie(REFRESH_COOKIE_NAME, {
      value: data[:value],
      httponly: true,
      secure: Rails.env.production?,
      same_site: Rails.env.production? ? :none : :lax,
      path: "/",
      expires: data[:expires]
    })
  end

  def delete_refresh_cookie
    response.delete_cookie(REFRESH_COOKIE_NAME, path: "/")
  end

  def read_refresh_cookie
    request.cookie_jar[REFRESH_COOKIE_NAME]
  end
end
