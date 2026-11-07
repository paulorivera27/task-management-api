# frozen_string_literal: true

# The frontend matches this exact message to trigger a token refresh (src/lib/apollo.ts).
module AuthGuard
  UNAUTHENTICATED_MESSAGE = "Authentication required"

  private

  def authenticated_user!
    context[:current_user] || raise(
      GraphQL::ExecutionError.new(UNAUTHENTICATED_MESSAGE, extensions: { code: "UNAUTHENTICATED" })
    )
  end
end
