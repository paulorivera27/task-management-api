# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    include AuthGuard

    MAX_PAGE_SIZE = 100

    field :tasks, Types::TasksResultType, null: false,
      description: "Fetches a page of the current user's tasks, newest first" do
      argument :status, Types::TaskStatusEnum, required: false,
        description: "Filter tasks by status."
      argument :limit, Integer, required: false, default_value: 10,
        description: "Number of tasks per page (1-#{MAX_PAGE_SIZE}). It will default to 10."
      argument :offset, Integer, required: false, default_value: 0,
        description: "Number of tasks to skip. It will default to 0."
    end

    def tasks(status: nil, limit: 10, offset: 0)
      user = authenticated_user!
      raise GraphQL::ExecutionError, "limit must be between 1 and #{MAX_PAGE_SIZE}" unless limit.between?(1, MAX_PAGE_SIZE)
      raise GraphQL::ExecutionError, "offset must be 0 or greater" if offset.negative?

      scope = user.tasks
      scope = scope.where(status: status) if status
      {
        tasks: scope.order(created_at: :desc, id: :desc).limit(limit).offset(offset),
        total_count: scope.count
      }
    end

    field :task, Types::TaskType,
      description: "returns a single task by ID." do
      argument :id, ID, required: true, description: "ID of the task."
    end

    def task(id:)
      user = authenticated_user!

      task = user.tasks.find_by(id: id)
      raise GraphQL::ExecutionError, "Task with ID #{id} not found." unless task

      task
    end

    field :current_user, Types::UserType, description: "returns the currently authenticated user."

    def current_user
      authenticated_user!
    end
  end
end
