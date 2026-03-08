# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Auth Mutations", type: :request do
  describe "signUp" do
    let(:query) do
      <<~GQL
        mutation($email: String!, $password: String!) {
          signUp(input: { email: $email, password: $password }) {
            token
            user { id email }
            errors
          }
        }
      GQL
    end

    it "creates a new user and returns a token" do
      post "/graphql", params: {
        query: query,
        variables: { email: "new@example.com", password: "password123" }.to_json
      }

      data = JSON.parse(response.body).dig("data", "signUp")
      expect(data["token"]).to be_present
      expect(data["user"]["email"]).to eq("new@example.com")
      expect(data["errors"]).to be_empty
    end

    it "returns errors for duplicate email" do
      create(:user, email: "taken@example.com")

      post "/graphql", params: {
        query: query,
        variables: { email: "taken@example.com", password: "password123" }.to_json
      }

      data = JSON.parse(response.body).dig("data", "signUp")
      expect(data["token"]).to be_nil
      expect(data["errors"]).not_to be_empty
    end

    it "returns errors for invalid email" do
      post "/graphql", params: {
        query: query,
        variables: { email: "not-an-email", password: "password123" }.to_json
      }

      data = JSON.parse(response.body).dig("data", "signUp")
      expect(data["token"]).to be_nil
      expect(data["errors"]).not_to be_empty
    end
  end

  describe "signIn" do
    let!(:user) { create(:user, email: "test@example.com", password: "password123") }

    let(:query) do
      <<~GQL
        mutation($email: String!, $password: String!) {
          signIn(input: { email: $email, password: $password }) {
            token
            user { id email }
            errors
          }
        }
      GQL
    end

    it "returns a token for valid credentials" do
      post "/graphql", params: {
        query: query,
        variables: { email: "test@example.com", password: "password123" }.to_json
      }

      data = JSON.parse(response.body).dig("data", "signIn")
      expect(data["token"]).to be_present
      expect(data["user"]["email"]).to eq("test@example.com")
      expect(data["errors"]).to be_empty
    end

    it "returns errors for wrong password" do
      post "/graphql", params: {
        query: query,
        variables: { email: "test@example.com", password: "wrongpassword" }.to_json
      }

      data = JSON.parse(response.body).dig("data", "signIn")
      expect(data["token"]).to be_nil
      expect(data["errors"]).to include("Invalid email or password.")
    end

    it "returns errors for non-existent email" do
      post "/graphql", params: {
        query: query,
        variables: { email: "ghost@example.com", password: "password123" }.to_json
      }

      data = JSON.parse(response.body).dig("data", "signIn")
      expect(data["token"]).to be_nil
      expect(data["errors"]).to include("Invalid email or password.")
    end
  end

  describe "currentUser query" do
    let(:user) { create(:user) }

    it "returns the authenticated user" do
      token = AuthToken.encode(user.id)

      post "/graphql",
        params: { query: "{ currentUser { id email } }" },
        headers: { "Authorization" => "Bearer #{token}" }

      data = JSON.parse(response.body).dig("data", "currentUser")
      expect(data["email"]).to eq(user.email)
    end

    it "returns an error when not authenticated" do
      post "/graphql", params: { query: "{ currentUser { id email } }" }

      result = JSON.parse(response.body)
      expect(result["errors"]).to be_present
    end
  end
end
