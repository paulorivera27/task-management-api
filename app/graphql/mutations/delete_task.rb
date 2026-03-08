# frozen_string_literal: true

module Mutations
  class DeleteTask < BaseMutation
    argument :id, ID, required: true, description: "ID of the task to delete."

    field :id, ID
    field :errors, [ String ], null: false

    def resolve(id:)
      user = context[:current_user] || raise(GraphQL::ExecutionError, "Authentication is required")

      task = user.tasks.find_by(id: id)
      return { id: nil, errors: [ "Task with ID #{id} not found." ] } unless task

      task.destroy!
      { id: task.id, errors: [] }
    end
  end
end
