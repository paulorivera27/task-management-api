# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    field :tasks, Types::TasksResultType, null: false,
      description: "Fetches a paginated list of tasks" do
      argument :status, Types::TaskStatusEnum, required: false,
        description: "Filter tasks by status."
      argument :limit, Integer, required: false, default_value: 10,
        description: "Number of tasks to return per page. It will default to 10."
      argument :offset, Integer, required: false, default_value: 0,
        description: "Number of tasks to skip. It will default to 0."
    end

    def tasks(status: nil, limit: 10, offset: 0)
      user = context[:current_user] || raise(GraphQL::ExecutionError, "Authentication is required")

      scope = user.tasks
      scope = scope.where(status: status) if status
      {
        tasks: scope.order(created_at: :desc).limit(limit).offset(offset),
        total_count: scope.count
      }
    end

    field :task, Types::TaskType,
      description: "returns a single task by ID." do
      argument :id, ID, required: true, description: "ID of the task."
    end

    def task(id:)
      user = context[:current_user] || raise(GraphQL::ExecutionError, "Authentication is required")

      task = user.tasks.find_by(id: id)
      raise GraphQL::ExecutionError, "Task with ID #{id} not found." unless task

      task
    end

    field :current_user, Types::UserType, description: "returns the currently authenticated user."

    def current_user
      context[:current_user] || raise(GraphQL::ExecutionError, "Authentication required")
    end
  end
end
