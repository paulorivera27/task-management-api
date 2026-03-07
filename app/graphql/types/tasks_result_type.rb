# frozen_string_literal: true

module Types
  class TasksResultType < Types::BaseObject
    description "Paginated list of tasks including the total count."

    field :tasks, [ Types::TaskType ], null: false,
      description: "List of tasks for the current page."
    field :total_count, Integer, null: false,
      description: "Total number of tasks matching the query."
  end
end
