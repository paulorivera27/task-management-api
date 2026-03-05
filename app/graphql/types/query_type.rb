# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    field :tasks, [ Types::TaskType ], null: false,
      description: "Fetches a list of all tasks." do
      argument :status, Types::TaskStatusEnum, required: false,
        description: "Filter tasks by status."
    end

    def tasks(status: nil)
     status ? Task.where(status: status) : Task.all
    end

    field :task, Types::TaskType,
      description: "returns a single task by ID." do
      argument :id, ID, required: true, description: "ID of the task."
    end

    def task(id:)
      task = Task.find_by(id: id)
      return raise GraphQL::ExecutionError, "Task with ID #{id} not found." unless task
      task
    end
  end
end
