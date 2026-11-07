# frozen_string_literal: true

require "rails_helper"

RSpec.describe AuthToken do
  it "round-trips a user id" do
    expect(described_class.decode(described_class.encode(42))).to eq(42)
  end

  it "rejects an expired token" do
    token = described_class.encode(42)
    travel 16.minutes

    expect(described_class.decode(token)).to be_nil
  end

  it "rejects a tampered token" do
    header, payload, signature = described_class.encode(42).split(".")
    forged = Base64.urlsafe_encode64({ user_id: 43, exp: 1.hour.from_now.to_i }.to_json, padding: false)

    expect(payload).not_to eq(forged)
    expect(described_class.decode([ header, forged, signature ].join("."))).to be_nil
  end

  it "rejects a token signed with another key" do
    token = JWT.encode({ user_id: 42, exp: 1.hour.from_now.to_i }, "x" * 64, "HS256")
    expect(described_class.decode(token)).to be_nil
  end

  it "rejects an unsigned token" do
    token = JWT.encode({ user_id: 42, exp: 1.hour.from_now.to_i }, nil, "none")
    expect(described_class.decode(token)).to be_nil
  end

  it "rejects garbage" do
    expect(described_class.decode("not.a.jwt")).to be_nil
  end

  it "is not signed with the raw secret_key_base" do
    token = JWT.encode({ user_id: 42, exp: 1.hour.from_now.to_i }, Rails.application.secret_key_base, "HS256")
    expect(described_class.decode(token)).to be_nil
  end
end
