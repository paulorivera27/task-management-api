# frozen_string_literal: true

module RefreshCookie
  extend ActiveSupport::Concern

  REFRESH_COOKIE_NAME = "refresh_token"
  REFRESH_COOKIE_PATH = "/auth"
  # Strict suits same-origin and same-site setups. Use "none" only when the frontend is on another site.
  REFRESH_COOKIE_SAME_SITE = ENV.fetch("REFRESH_COOKIE_SAMESITE", "strict").downcase.to_sym.tap do |value|
    raise ArgumentError, "REFRESH_COOKIE_SAMESITE must be strict, lax or none" unless %i[strict lax none].include?(value)
  end

  private

  # request.ssl? is always true when config.assume_ssl is on, so Secure follows the TLS switch.
  def set_refresh_cookie(data)
    response.set_cookie(REFRESH_COOKIE_NAME, {
      value: data[:value],
      httponly: true,
      secure: request.ssl?,
      same_site: REFRESH_COOKIE_SAME_SITE,
      path: REFRESH_COOKIE_PATH,
      expires: data[:expires]
    })
  end

  def delete_refresh_cookie
    response.delete_cookie(REFRESH_COOKIE_NAME, path: REFRESH_COOKIE_PATH, httponly: true, secure: request.ssl?, same_site: REFRESH_COOKIE_SAME_SITE)
    expire_legacy_refresh_cookie
  end

  # Before cookies were scoped to /auth they used Path=/.
  def expire_legacy_refresh_cookie
    response.delete_cookie(REFRESH_COOKIE_NAME, path: "/")
  end

  def read_refresh_cookie
    request.cookie_jar[REFRESH_COOKIE_NAME]
  end
end
