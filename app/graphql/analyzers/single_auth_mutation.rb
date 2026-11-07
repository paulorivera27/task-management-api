# frozen_string_literal: true

module Analyzers
  # Aliasing signIn many times in one request would bypass per-request rate limits.
  class SingleAuthMutation < GraphQL::Analysis::Analyzer
    AUTH_FIELDS = %w[signIn signUp].freeze

    def initialize(query_or_multiplex)
      super
      @count = 0
    end

    def on_enter_field(node, _parent, visitor)
      return unless AUTH_FIELDS.include?(node.name) && visitor.parent_type_definition == Types::MutationType

      @count += 1
    end

    def result
      return if @count <= 1

      GraphQL::AnalysisError.new("Only one signIn or signUp is allowed per request")
    end
  end
end
