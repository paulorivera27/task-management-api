# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GraphQL security and input handling", type: :request do
  let(:user) { create(:user) }

  def gql(query, variables: {}, headers: {})
    post "/graphql", params: { query: query, variables: variables }, headers: headers, as: :json
    JSON.parse(response.body)
  end

  def error_messages(result)
    Array(result["errors"]).map { |e| e["message"] }
  end

  describe "transport" do
    it "rejects form-encoded bodies with 415" do
      post "/graphql", params: { query: "{ currentUser { id } }" }

      expect(response).to have_http_status(:unsupported_media_type)
    end

    it "rejects text/plain bodies with 415" do
      post "/graphql", params: { query: "{ currentUser { id } }" }.to_json, headers: { "Content-Type" => "text/plain" }

      expect(response).to have_http_status(:unsupported_media_type)
    end

    it "accepts variables sent as a JSON string" do
      post "/graphql",
        params: { query: "query($n: Int) { tasks(limit: $n) { totalCount } }", variables: { n: 5 }.to_json },
        headers: auth_headers(user), as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).dig("data", "tasks", "totalCount")).to eq(0)
    end

    it "returns 400 for variables that are not valid JSON" do
      post "/graphql", params: { query: "{ currentUser { id } }", variables: "{nope" }, as: :json

      expect(response).to have_http_status(:bad_request)
    end

    it "returns 400 for variables that are not an object" do
      post "/graphql", params: { query: "{ currentUser { id } }", variables: "[1]" }, as: :json

      expect(response).to have_http_status(:bad_request)
    end

    it "rate limits to 60 requests per minute and says when to retry" do
      60.times { post "/graphql", params: { query: "{ __typename }" }, as: :json }
      expect(response).to have_http_status(:ok)

      post "/graphql", params: { query: "{ __typename }" }, as: :json

      expect(response).to have_http_status(:too_many_requests)
      expect(response.headers["Retry-After"]).to eq("60")
    end
  end

  describe "authentication" do
    let(:task) { create(:task, user: user) }

    {
      "tasks" => "{ tasks { totalCount } }",
      "task" => '{ task(id: "1") { id } }',
      "currentUser" => "{ currentUser { id } }",
      "createTask" => 'mutation { createTask(input: { title: "x" }) { errors } }',
      "updateTask" => 'mutation { updateTask(input: { id: "1", title: "x" }) { errors } }',
      "deleteTask" => 'mutation { deleteTask(input: { id: "1" }) { errors } }'
    }.each do |name, document|
      it "#{name} returns the exact message the frontend refreshes on, with an UNAUTHENTICATED code" do
        result = gql(document)

        expect(result["errors"].first["message"]).to eq("Authentication required")
        expect(result["errors"].first.dig("extensions", "code")).to eq("UNAUTHENTICATED")
      end
    end

    it "ignores a non-Bearer Authorization scheme" do
      token = AuthToken.encode(user.id)

      result = gql("{ currentUser { id } }", headers: { "Authorization" => "Basic #{token}" })

      expect(error_messages(result)).to eq([ "Authentication required" ])
    end

    it "treats an expired access token as unauthenticated" do
      headers = auth_headers(user)
      travel 16.minutes

      result = gql("{ currentUser { id } }", headers: headers)

      expect(error_messages(result)).to eq([ "Authentication required" ])
    end

    it "treats a token for a deleted user as unauthenticated" do
      headers = auth_headers(user)
      user.destroy!

      result = gql("{ currentUser { id } }", headers: headers)

      expect(error_messages(result)).to eq([ "Authentication required" ])
    end
  end

  describe "pagination bounds" do
    def tasks(args = nil)
      arguments = args ? "(#{args})" : ""
      gql("{ tasks#{arguments} { totalCount tasks { id } } }", headers: auth_headers(user))
    end

    it "rejects limit 0" do
      expect(error_messages(tasks("limit: 0"))).to eq([ "limit must be between 1 and 100" ])
    end

    it "rejects limit above 100" do
      expect(error_messages(tasks("limit: 101"))).to eq([ "limit must be between 1 and 100" ])
    end

    it "rejects a negative limit" do
      expect(error_messages(tasks("limit: -1"))).to eq([ "limit must be between 1 and 100" ])
    end

    it "rejects a negative offset" do
      expect(error_messages(tasks("offset: -1"))).to eq([ "offset must be 0 or greater" ])
    end

    it "accepts limit 100" do
      expect(tasks("limit: 100")["errors"]).to be_nil
    end

    it "pages are disjoint and complete even when created_at ties" do
      stamp = Time.current.change(usec: 0)
      created = create_list(:task, 5, user: user, created_at: stamp)

      ids = [ 0, 2, 4 ].flat_map { |offset| tasks("limit: 2, offset: #{offset}").dig("data", "tasks", "tasks").map { |t| t["id"].to_i } }

      expect(ids).to match_array(created.map(&:id))
      expect(ids).to eq(ids.uniq)
    end

    it "orders newest first" do
      older = create(:task, user: user, created_at: 2.days.ago)
      newer = create(:task, user: user, created_at: 1.day.ago)

      ids = tasks.dig("data", "tasks", "tasks").map { |t| t["id"].to_i }

      expect(ids).to eq([ newer.id, older.id ])
    end
  end

  describe "auth mutation budget" do
    let(:query) do
      <<~GQL
        mutation {
          a: signIn(input: { email: "a@example.com", password: "password123" }) { errors }
          b: signIn(input: { email: "b@example.com", password: "password123" }) { errors }
        }
      GQL
    end

    it "rejects several aliased signIn calls in one request" do
      result = gql(query)

      expect(error_messages(result)).to eq([ "Only one signIn or signUp is allowed per request" ])
      expect(result["data"]).to be_nil
    end

    it "still allows a single signIn" do
      result = gql('mutation { signIn(input: { email: "a@example.com", password: "password123" }) { errors } }')

      expect(result.dig("data", "signIn", "errors")).to eq([ "Invalid email or password." ])
    end
  end

  describe "signUp" do
    let(:query) do
      'mutation($e: String!, $p: String!) { signUp(input: { email: $e, password: $p }) { token errors } }'
    end

    it "rejects a short password" do
      result = gql(query, variables: { e: "short@example.com", p: "short" })

      expect(result.dig("data", "signUp", "token")).to be_nil
      expect(result.dig("data", "signUp", "errors")).to include("Password is too short (minimum is 8 characters)")
    end

    it "returns an errors payload when the unique index wins a race" do
      allow_any_instance_of(User).to receive(:save).and_raise(ActiveRecord::RecordNotUnique)

      result = gql(query, variables: { e: "race@example.com", p: "password123" })

      expect(response).to have_http_status(:ok)
      expect(result.dig("data", "signUp", "errors")).to eq([ "Email has already been taken" ])
    end
  end

  describe "updateTask" do
    let(:mutation) do
      'mutation($id: ID!, $d: String) { updateTask(input: { id: $id, description: $d }) { task { description } errors } }'
    end

    it "clears the description when null is sent explicitly" do
      task = create(:task, user: user, description: "keep me")

      result = gql(mutation, variables: { id: task.id.to_s, d: nil }, headers: auth_headers(user))

      expect(result.dig("data", "updateTask", "errors")).to be_empty
      expect(task.reload.description).to be_nil
    end

    it "leaves the description untouched when it is omitted" do
      task = create(:task, user: user, description: "keep me")

      gql('mutation($id: ID!) { updateTask(input: { id: $id, title: "New" }) { errors } }',
        variables: { id: task.id.to_s }, headers: auth_headers(user))

      expect(task.reload.description).to eq("keep me")
      expect(task.title).to eq("New")
    end

    it "does not modify another user's task" do
      task = create(:task, user: create(:user), title: "Theirs")

      result = gql(mutation, variables: { id: task.id.to_s, d: "mine" }, headers: auth_headers(user))

      expect(result.dig("data", "updateTask", "errors")).to eq([ "Not found" ])
      expect(task.reload.description).not_to eq("mine")
      expect(task.title).to eq("Theirs")
    end

    it "rejects a blank title" do
      task = create(:task, user: user)

      result = gql('mutation($id: ID!) { updateTask(input: { id: $id, title: "" }) { task { id } errors } }',
        variables: { id: task.id.to_s }, headers: auth_headers(user))

      expect(result.dig("data", "updateTask", "errors")).to include("Title can't be blank")
    end
  end
end
