# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GraphQL Tasks", type: :request do
  def query(query_string, variables: {})
    post "/graphql", params: { query: query_string, variables: variables.to_json }
    JSON.parse(response.body)
  end

  describe "queries" do
    describe "tasks" do
      it "returns all tasks" do
        create_list(:task, 3)
        result = query("{ tasks { id title status } }")
        expect(result["data"]["tasks"].length).to eq(3)
      end

      it "filters tasks by status" do
        create_list(:task, 2)
        create(:task, :in_progress)
        result = query("{ tasks(status: IN_PROGRESS) { id status } }")
        expect(result["data"]["tasks"].length).to eq(1)
        expect(result["data"]["tasks"].first["status"]).to eq("IN_PROGRESS")
      end

      it "returns empty array when no tasks exist" do
        result = query("{ tasks { id } }")
        expect(result["data"]["tasks"]).to eq([])
      end
    end

    describe "task" do
      it "returns a single task by ID" do
        task = create(:task)
        result = query("{ task(id: #{task.id}) { id title description status } }")
        expect(result["data"]["task"]["title"]).to eq(task.title)
      end

      it "returns an error for non-existent task" do
        result = query("{ task(id: 999) { id } }")
        expect(result["errors"]).to be_present
      end
    end
  end

  describe "mutations" do
    describe "createTask" do
      it "creates a task with valid input" do
        result = query('mutation { createTask(input: { title: "Test task" }) { task { id title status } errors } }')
        data = result["data"]["createTask"]
        expect(data["task"]["title"]).to eq("Test task")
        expect(data["task"]["status"]).to eq("PENDING")
        expect(data["errors"]).to be_empty
      end

      it "returns errors with invalid input" do
        result = query('mutation { createTask(input: { title: "" }) { task { id } errors } }')
        data = result["data"]["createTask"]
        expect(data["task"]).to be_nil
        expect(data["errors"]).to include("Title can't be blank")
      end
    end

    describe "updateTask" do
      it "updates a task" do
        task = create(:task, title: "Old title")
        result = query(
          'mutation($id: ID!, $title: String) { updateTask(input: { id: $id, title: $title }) { task { id title } errors } }',
          variables: { id: task.id.to_s, title: "New title" }
        )
        data = result["data"]["updateTask"]
        expect(data["task"]["title"]).to eq("New title")
        expect(data["errors"]).to be_empty
      end

      it "returns errors for non-existent task" do
        result = query('mutation { updateTask(input: { id: "999", title: "I don\'t exist" }) { task { id } errors } }')
        data = result["data"]["updateTask"]
        expect(data["task"]).to be_nil
        expect(data["errors"]).to be_present
      end
    end

    describe "deleteTask" do
      it "deletes a task" do
        task = create(:task)
        result = query("mutation { deleteTask(input: { id: \"#{task.id}\" }) { id errors } }")
        data = result["data"]["deleteTask"]
        expect(data["id"]).to eq(task.id.to_s)
        expect(data["errors"]).to be_empty
        expect(Task.find_by(id: task.id)).to be_nil
      end

      it "returns errors for non-existent task" do
        result = query('mutation { deleteTask(input: { id: "999" }) { id errors } }')
        data = result["data"]["deleteTask"]
        expect(data["errors"]).to be_present
      end
    end
  end
end
