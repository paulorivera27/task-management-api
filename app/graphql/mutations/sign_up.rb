# frozen_string_literal: true

module Mutations
  class SignUp < BaseMutation
    argument :email, String, required: true, description: "Email address of the new user."
    argument :password, String, required: true, description: "The password for the new user."

    field :token, String
    field :user, Types::UserType
    field :errors, [ String ], null: false

    def resolve(email:, password:)
      user = User.new(email: email, password: password)

      if user.save
        token = AuthToken.encode(user.id)
        set_refresh_cookie(user)
        { user: user, token:, errors: [] }
      else
        { user: nil, token: nil, errors: user.errors.full_messages }
      end
    end

    private

    def set_refresh_cookie(user)
      raw_token, _refresh_token = RefreshToken.generate_for(user)
      context[:refresh_cookie_data].merge!(
        value: raw_token,
        expires: RefreshToken::EXPIRATION.from_now
      )
    end
  end
end
