if Rails.env.development?
  Rails.application.config.middleware.use ActionDispatch::Cookies
  Rails.application.config.middleware.use ActionDispatch::Session::CookieStore, key: "_task_management_api_session"
end
