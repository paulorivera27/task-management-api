# frozen_string_literal: true

module Types
  class TaskStatusEnum < Types::BaseEnum
    value "PENDING", "The task is not yet started.", value: "pending"
    value "IN_PROGRESS", "The task is in progress.", value: "in_progress"
    value "COMPLETED", "The task is complete.", value: "completed"
  end
end
