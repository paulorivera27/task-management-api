# frozen_string_literal: true

require "rails_helper"

RSpec.describe Task, type: :model do
  describe "validations" do
    it "valid when a title is present" do
      task = build(:task)
      expect(task).to be_valid
    end

    it "invalid without a title" do
      task = build(:task, title: nil)
      expect(task).not_to be_valid
      expect(task.errors[:title]).to include("can't be blank")
    end
  end

  describe "enum" do
    it "properly defines the statuses" do
      expect(Task.statuses).to eq({ "pending" => 0, "in_progress" => 1, "completed" => 2 })
    end

    it "pending is the default status" do
      task = create(:task)
      expect(task.status).to eq("pending")
    end
  end
end
