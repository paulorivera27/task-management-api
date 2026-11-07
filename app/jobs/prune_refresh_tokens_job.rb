# frozen_string_literal: true

class PruneRefreshTokensJob < ApplicationJob
  queue_as :default

  def perform
    RefreshToken.prune!
  end
end
