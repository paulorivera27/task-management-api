# frozen_string_literal: true

module Mutations
  class BaseMutation < GraphQL::Schema::RelayClassicMutation
    argument_class Types::BaseArgument
    field_class Types::BaseField
    input_object_class Types::BaseInputObject
    object_class Types::BaseObject

    private

    # Starts a new refresh-token family; the controller writes the cookie after execution.
    def start_session(user)
      raw_token, refresh_token = RefreshToken.generate_for(user)
      context[:refresh_cookie_data].merge!(value: raw_token, expires: refresh_token.expires_at)
      AuthToken.encode(user.id)
    end
  end
end
