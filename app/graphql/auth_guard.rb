# frozen_string_literal: true

# The frontend refreshes the token on extensions.code UNAUTHENTICATED; it still accepts this exact message
# as a fallback (task-management-frontend, src/lib/errors.ts).
module AuthGuard
  UNAUTHENTICATED_MESSAGE = "Authentication required"

  private

  def authenticated_user!
    context[:current_user] || raise(
      GraphQL::ExecutionError.new(UNAUTHENTICATED_MESSAGE, extensions: { code: "UNAUTHENTICATED" })
    )
  end
end
