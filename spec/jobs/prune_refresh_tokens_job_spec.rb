# frozen_string_literal: true

require "rails_helper"

RSpec.describe PruneRefreshTokensJob do
  it "prunes dead refresh tokens" do
    _, token = RefreshToken.generate_for(create(:user))
    token.update!(absolute_expires_at: 1.minute.ago)

    expect { described_class.perform_now }.to change(RefreshToken, :count).from(1).to(0)
  end
end
