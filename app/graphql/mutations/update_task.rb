# frozen_string_literal: true

module Mutations
  class UpdateTask < BaseMutation
    argument :id, ID, required: true, description: "ID of the task to update."
    argument :title, String, required: false, description: "The updated title for the task."
    argument :description, String, required: false, description: "Updated task description or details."
    argument :status, Types::TaskStatusEnum, required: false, description: "Updated task status."

    field :task, Types::TaskType
    field :errors, [ String ], null: false

    def resolve(id:, **attributes)
      task = Task.find_by(id: id)
      return { task: nil, errors: [ "Not found" ] } unless task

      attributes.compact!

      if task.update(attributes)
        { task: task, errors: [] }
      else
        { task: nil, errors: task.errors.full_messages }
      end
    end
  end
end
