# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      user = build(:user)
      expect(user).to be_valid
    end

    it "requires an email" do
      user = build(:user, email: nil)
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("can't be blank")
    end

    it "requires a unique email" do
      create(:user, email: "test@example.com")
      duplicate = build(:user, email: "Test@Example.com")
      expect(duplicate).not_to be_valid
    end

    it "requires a valid email format" do
      user = build(:user, email: "not-an-email")
      expect(user).not_to be_valid
    end

    it "downcases email before saving" do
      user = create(:user, email: "Test@Example.COM")
      expect(user.email).to eq("test@example.com")
    end

    it "requires a password" do
      user = build(:user, password: nil)
      expect(user).not_to be_valid
    end

    it "rejects passwords shorter than 8 characters" do
      user = build(:user, password: "short12")
      expect(user).not_to be_valid
      expect(user.errors[:password].join).to include("too short")
    end

    it "accepts an 8 character password" do
      expect(build(:user, password: "exactly8")).to be_valid
    end

    it "rejects passwords over bcrypt's 72 byte limit" do
      expect(build(:user, password: "a" * 73)).not_to be_valid
    end
  end

  describe "associations" do
    it "has many tasks" do
      assoc = described_class.reflect_on_association(:tasks)
      expect(assoc.macro).to eq(:has_many)
    end

    it "destroys associated tasks when user is deleted" do
      user = create(:user)
      create(:task, user: user)
      expect { user.destroy }.to change(Task, :count).by(-1)
    end
  end
end
