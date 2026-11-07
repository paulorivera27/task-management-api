# frozen_string_literal: true

require "rails_helper"

RSpec.describe RefreshToken, type: :model do
  let(:user) { create(:user) }

  describe ".generate_for" do
    it "stores only the digest and starts a new family" do
      raw, token = described_class.generate_for(user)

      expect(token.token_digest).to eq(Digest::SHA256.hexdigest(raw))
      expect(token.token_digest).not_to eq(raw)
      expect(token.family_id).to be_present
      expect(token.expires_at).to be_within(5.seconds).of(7.days.from_now)
      expect(token.absolute_expires_at).to be_within(5.seconds).of(30.days.from_now)
    end

    it "gives each login its own family" do
      _, first = described_class.generate_for(user)
      _, second = described_class.generate_for(user)

      expect(first.family_id).not_to eq(second.family_id)
    end
  end

  describe ".find_by_raw_token" do
    it "finds by raw value" do
      raw, token = described_class.generate_for(user)
      expect(described_class.find_by_raw_token(raw)).to eq(token)
    end

    it "returns nil for blank or unknown values" do
      expect(described_class.find_by_raw_token(nil)).to be_nil
      expect(described_class.find_by_raw_token("")).to be_nil
      expect(described_class.find_by_raw_token("nope")).to be_nil
    end
  end

  describe ".prune!" do
    it "removes sessions past their absolute lifetime and long-revoked rows, keeping live ones" do
      _, live = described_class.generate_for(user)
      _, expired = described_class.generate_for(user)
      expired.update!(absolute_expires_at: 1.minute.ago)
      _, old_revoked = described_class.generate_for(user)
      old_revoked.update!(revoked_at: 2.days.ago)
      _, fresh_revoked = described_class.generate_for(user)
      fresh_revoked.update!(revoked_at: 1.hour.ago)

      described_class.prune!

      expect(described_class.all).to contain_exactly(live, fresh_revoked)
    end
  end

  describe "#rotate!" do
    it "issues a child in the same family and marks the parent rotated" do
      _, parent = described_class.generate_for(user)

      outcome, raw, child = parent.rotate!

      expect(outcome).to eq(:rotated)
      expect(child.family_id).to eq(parent.family_id)
      expect(child.absolute_expires_at).to eq(parent.absolute_expires_at)
      expect(described_class.find_by_raw_token(raw)).to eq(child)
      expect(parent.reload.rotated_at).to be_present
    end

    it "hands a sibling to a replay inside the grace window so a lost response does not end the session" do
      _, parent = described_class.generate_for(user)
      _, _, first = parent.rotate!

      outcome, raw, second = parent.rotate!

      expect(outcome).to eq(:rotated)
      expect(second.parent).to eq(parent)
      expect(second.id).not_to eq(first.id)
      expect(described_class.find_by_raw_token(raw)).to eq(second)
      expect(first.reload.rotated_at).to be_nil
    end

    it "does not fork the chain when a child was already used (quick reloads, then a replay of the parent)" do
      _, parent = described_class.generate_for(user)
      _, _, child = parent.rotate!
      child.rotate!

      expect { expect(parent.rotate!).to eq([ :grace ]) }.not_to change(described_class, :count)
    end

    it "does not fork the chain after a recovery was used and the parent is replayed again" do
      _, parent = described_class.generate_for(user)
      parent.rotate!
      _, _, recovered = parent.rotate!
      recovered.rotate!

      expect { expect(parent.rotate!).to eq([ :grace ]) }.not_to change(described_class, :count)
    end

    it "caps the siblings handed out inside the grace window" do
      _, parent = described_class.generate_for(user)
      3.times { parent.rotate! }

      expect { expect(parent.rotate!).to eq([ :grace ]) }.not_to change(described_class, :count)
      expect(parent.children.count).to eq(3)
    end

    it "retires the other siblings once one is used" do
      _, parent = described_class.generate_for(user)
      _, _, lost = parent.rotate!
      _, _, recovered = parent.rotate!

      expect(recovered.rotate!.first).to eq(:rotated)

      expect(lost.reload.rotated_at).to be_present
      expect { expect(lost.rotate!).to eq([ :grace ]) }.not_to change(described_class, :count)
      travel 11.seconds
      expect(lost.rotate!).to eq([ :reuse ])
      expect(recovered.reload).to be_revoked
    end

    it "catches a thief who replayed the parent when the legitimate holder refreshes second" do
      _, parent = described_class.generate_for(user)
      _, _, legit = parent.rotate!
      _, _, thief = parent.rotate!

      expect(thief.rotate!.first).to eq(:rotated)
      travel 11.seconds

      expect(legit.rotate!).to eq([ :reuse ])
      expect(described_class.where(family_id: parent.family_id).where(revoked_at: nil)).to be_empty
    end

    it "catches a thief who replayed the parent when the thief refreshes second" do
      _, parent = described_class.generate_for(user)
      _, _, legit = parent.rotate!
      _, _, thief = parent.rotate!

      expect(legit.rotate!.first).to eq(:rotated)
      travel 11.seconds

      expect(thief.rotate!).to eq([ :reuse ])
      expect(described_class.where(family_id: parent.family_id).where(revoked_at: nil)).to be_empty
    end

    it "treats a replay after the grace window as reuse and revokes the family" do
      _, parent = described_class.generate_for(user)
      _, _, child = parent.rotate!

      travel 11.seconds

      expect(parent.rotate!).to eq([ :reuse ])
      expect(child.reload).to be_revoked
      expect(parent.reload).to be_revoked
    end

    it "does not touch other families on reuse" do
      _, other = described_class.generate_for(user)
      _, parent = described_class.generate_for(user)
      parent.rotate!
      travel 11.seconds

      parent.rotate!

      expect(other.reload).not_to be_revoked
    end

    it "is invalid once revoked" do
      _, token = described_class.generate_for(user)
      token.revoke_family!

      expect(token.reload.rotate!).to eq([ :invalid ])
    end

    it "is invalid once expired" do
      _, token = described_class.generate_for(user)
      travel 8.days

      expect(token.rotate!).to eq([ :invalid ])
    end

    it "never extends a child past the absolute lifetime" do
      freeze_time
      _, token = described_class.generate_for(user)
      4.times do
        travel 6.days
        _, _, token = token.rotate!
      end

      expect(token.expires_at).to eq(token.absolute_expires_at)
      travel 6.days
      expect(token.rotate!).to eq([ :invalid ])
    end
  end
end
