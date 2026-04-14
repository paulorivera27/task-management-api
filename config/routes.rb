Rails.application.routes.draw do
  post "/graphql", to: "graphql#execute"

  post "/auth/refresh", to: "auth#refresh"
  delete "/auth/logout", to: "auth#logout"

  if Rails.env.development?
    mount GraphiQL::Rails::Engine, at: "/graphiql", graphql_path: "/graphql"
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end
