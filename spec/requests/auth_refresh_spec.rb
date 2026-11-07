# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Refresh and logout", type: :request do
  let!(:user) { create(:user, email: "session@example.com", password: "password123") }

  let(:sign_in_query) do
    <<~GQL
      mutation($email: String!, $password: String!) {
        signIn(input: { email: $email, password: $password }) { token errors }
      }
    GQL
  end

  def sign_in
    post "/graphql", params: { query: sign_in_query, variables: { email: user.email, password: "password123" } }, as: :json
  end

  def set_cookie_header
    Array(response.headers["Set-Cookie"]).join("\n")
  end

  def cookie_value
    set_cookie_header[/^refresh_token=([^;\s]+)/, 1]
  end

  def refresh_with(raw)
    reset!
    post "/auth/refresh", headers: { "Cookie" => "refresh_token=#{raw}" }
  end

  describe "cookie attributes" do
    it "sets a Secure HttpOnly SameSite=Strict cookie scoped to /auth over TLS" do
      https!
      sign_in

      expect(set_cookie_header).to match(/refresh_token=[^;]+/)
      expect(set_cookie_header).to include("path=/auth")
      expect(set_cookie_header.downcase).to include("httponly", "secure", "samesite=strict")
      expect(set_cookie_header.downcase).to include("expires=")
    end

    it "omits Secure over plain HTTP so the local demo works" do
      sign_in

      expect(set_cookie_header).to match(/refresh_token=[^;]+/)
      expect(set_cookie_header.downcase).not_to include("secure")
    end
  end

  describe "POST /auth/refresh" do
    it "returns a new access token and user, and rotates the cookie" do
      sign_in
      first = cookie_value

      post "/auth/refresh"

      body = JSON.parse(response.body)
      expect(response).to have_http_status(:ok)
      expect(body["token"]).to be_present
      expect(AuthToken.decode(body["token"])).to eq(user.id)
      expect(body["user"]).to eq({ "id" => user.id, "email" => "session@example.com" })
      expect(response.headers["Cache-Control"]).to eq("no-store")
      expect(cookie_value).to be_present
      expect(cookie_value).not_to eq(first)
      expect(set_cookie_header).to include("refresh_token=; path=/;")
      expect(RefreshToken.where(user: user).distinct.pluck(:family_id).size).to eq(1)
    end

    it "returns 401 and clears the cookie without a refresh cookie" do
      post "/auth/refresh"

      expect(response).to have_http_status(:unauthorized)
      expect(set_cookie_header.downcase).to include("refresh_token=;").or include("max-age=0")
    end

    it "returns 401 for an unknown token" do
      refresh_with("unknown")

      expect(response).to have_http_status(:unauthorized)
    end

    it "recovers from a lost refresh response with a sibling cookie" do
      sign_in
      first = cookie_value
      refresh_with(first)
      lost = cookie_value

      refresh_with(first)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["token"]).to be_present
      recovered = cookie_value
      expect(recovered).to be_present
      expect(recovered).not_to eq(lost)
      refresh_with(recovered)
      expect(response).to have_http_status(:ok)
    end

    it "answers a replay after a child was used with a token but no new cookie" do
      sign_in
      first = cookie_value
      refresh_with(first)
      refresh_with(cookie_value)

      refresh_with(first)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["token"]).to be_present
      expect(set_cookie_header).to be_empty
    end

    it "revokes the family when the sibling that lost the race is presented after the window" do
      sign_in
      first = cookie_value
      refresh_with(first)
      lost = cookie_value
      refresh_with(first)
      refresh_with(cookie_value)
      travel 11.seconds

      refresh_with(lost)

      expect(response).to have_http_status(:unauthorized)
      expect(RefreshToken.where(user: user).where(revoked_at: nil)).to be_empty
    end

    it "revokes the whole family when a rotated token is replayed after the grace window" do
      sign_in
      first = cookie_value
      post "/auth/refresh"
      second = cookie_value
      travel 11.seconds

      refresh_with(first)
      expect(response).to have_http_status(:unauthorized)

      refresh_with(second)
      expect(response).to have_http_status(:unauthorized)
      expect(RefreshToken.where(user: user).where(revoked_at: nil)).to be_empty
    end

    it "rejects an idle-expired token" do
      sign_in
      raw = cookie_value
      travel 8.days

      refresh_with(raw)

      expect(response).to have_http_status(:unauthorized)
    end

    it "stops refreshing after the absolute session lifetime" do
      freeze_time
      sign_in
      raw = cookie_value
      4.times do
        travel 6.days
        refresh_with(raw)
        expect(response).to have_http_status(:ok)
        raw = cookie_value
      end

      travel 6.days
      refresh_with(raw)

      expect(response).to have_http_status(:unauthorized)
    end

    it "rate limits to 120 requests per minute and says when to retry" do
      120.times { post "/auth/refresh" }
      expect(response).to have_http_status(:unauthorized)

      post "/auth/refresh"

      expect(response).to have_http_status(:too_many_requests)
      expect(response.headers["Retry-After"]).to eq("60")
    end
  end

  describe "DELETE /auth/logout" do
    it "revokes the whole family and clears the cookie" do
      sign_in
      raw = cookie_value
      post "/auth/refresh"

      delete "/auth/logout"

      expect(response).to have_http_status(:no_content)
      expect(set_cookie_header).to include("path=/auth").and include("max-age=0")
      expect(RefreshToken.where(user: user).where(revoked_at: nil)).to be_empty
      refresh_with(raw)
      expect(response).to have_http_status(:unauthorized)
    end

    it "is idempotent without a cookie" do
      delete "/auth/logout"

      expect(response).to have_http_status(:no_content)
    end
  end
end
