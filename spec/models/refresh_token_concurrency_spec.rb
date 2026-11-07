# frozen_string_literal: true

require "rails_helper"

# Real threads and real commits: transactional tests would serialize everything on one connection.
RSpec.describe RefreshToken, "concurrency" do
  self.use_transactional_tests = false

  ITERATIONS = 25

  after do
    RefreshToken.delete_all
    User.delete_all
  end

  def concurrently(*actions)
    start = Queue.new
    threads = actions.map do |action|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          start.pop
          action.call
        rescue StandardError => e
          e
        end
      end
    end
    actions.size.times { start << :go }
    threads.map(&:value)
  end

  def live_heads(family_id)
    described_class.where(family_id: family_id, rotated_at: nil, revoked_at: nil).count
  end

  it "never leaves two live heads when a parent replay races the first use of its child" do
    ITERATIONS.times do
      user = create(:user)
      _, parent = described_class.generate_for(user)
      _, _, child = parent.rotate!

      results = concurrently(-> { described_class.find(parent.id).rotate! }, -> { described_class.find(child.id).rotate! })

      expect(results.grep(StandardError)).to be_empty
      expect(live_heads(parent.family_id)).to eq(1)
    end
  end

  it "does not deadlock when two siblings are used at the same time" do
    ITERATIONS.times do
      user = create(:user)
      _, parent = described_class.generate_for(user)
      _, _, first = parent.rotate!
      _, _, second = parent.rotate!

      results = concurrently(-> { described_class.find(first.id).rotate! }, -> { described_class.find(second.id).rotate! })

      expect(results.grep(StandardError)).to be_empty
      expect(live_heads(parent.family_id)).to eq(1)
    end
  end

  it "revokes the child created by a rotation that races a revoke" do
    ITERATIONS.times do
      user = create(:user)
      _, head = described_class.generate_for(user)

      results = concurrently(-> { described_class.find(head.id).rotate! }, -> { described_class.find(head.id).revoke_family! })

      expect(results.grep(StandardError)).to be_empty
      expect(described_class.where(family_id: head.family_id, revoked_at: nil)).to be_empty
    end
  end
end
