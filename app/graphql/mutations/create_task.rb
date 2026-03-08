# frozen_string_literal: true

module Mutations
  class CreateTask < BaseMutation
    argument :title, String, required: true, description: "The title for the task."
    argument :description, String, required: false, description: "Task description or details."
    argument :status, Types::TaskStatusEnum, required: false, description: "Initial task status."

    field :task, Types::TaskType
    field :errors, [ String ], null: false

    def resolve(title:, description: nil, status: nil)
      user = context[:current_user] || raise(GraphQL::ExecutionError, "Authentication is required")

      task = user.tasks.new(title: title, description: description, status: status || "pending")

      if task.save
        { task:, errors: [] }
      else
        { task: nil, errors: task.errors.full_messages }
      end
    end
  end
end
