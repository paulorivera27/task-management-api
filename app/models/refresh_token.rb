# frozen_string_literal: true

# Single-use refresh tokens grouped into a family (one login session).
# Presenting a token that was already rotated, after the grace window,
# is treated as theft and revokes the whole family.
#
# Inside the grace window a replay gets a sibling child, so a refresh response lost in transit does not
# end the session. Once one sibling is used the others are retired, so the first side to refresh wins and
# the other side is caught by the reuse check.
class RefreshToken < ApplicationRecord
  EXPIRATION = 7.days
  ABSOLUTE_EXPIRATION = 30.days
  REUSE_GRACE = 10.seconds
  MAX_SIBLINGS = 3
  TOKEN_LENGTH = 32

  belongs_to :user
  belongs_to :parent, class_name: "RefreshToken", optional: true
  has_many :children, class_name: "RefreshToken", foreign_key: :parent_id, inverse_of: :parent, dependent: nil

  validates :token_digest, presence: true, uniqueness: true
  validates :family_id, :expires_at, :absolute_expires_at, presence: true

  def self.digest(raw_token)
    Digest::SHA256.hexdigest(raw_token)
  end

  def self.generate_for(user)
    issue(user: user, family_id: SecureRandom.uuid, absolute_expires_at: ABSOLUTE_EXPIRATION.from_now)
  end

  def self.issue(user:, family_id:, absolute_expires_at:, parent: nil)
    raw_token = SecureRandom.urlsafe_base64(TOKEN_LENGTH)
    refresh_token = create!(
      user: user,
      parent: parent,
      token_digest: digest(raw_token),
      family_id: family_id,
      absolute_expires_at: absolute_expires_at,
      expires_at: [ EXPIRATION.from_now, absolute_expires_at ].min
    )
    [ raw_token, refresh_token ]
  end

  # Rows past the session lifetime, or revoked more than a day ago, can never be used again.
  def self.prune!
    where(absolute_expires_at: ...Time.current).or(where(revoked_at: ...1.day.ago)).delete_all
  end

  # Every change to a family runs under one advisory lock. Row locks alone let concurrent rotations of
  # different rows in the same family fork the chain, deadlock, or miss a row that is being inserted.
  def self.with_family_lock(family_id)
    transaction do
      connection.select_value(sanitize_sql_array([ "SELECT pg_advisory_xact_lock(hashtext(?))", family_id ]))
      yield
    end
  end

  def self.find_by_raw_token(raw_token)
    return nil if raw_token.blank?

    find_by(token_digest: digest(raw_token))
  end

  # Returns [:rotated, raw_token, new_record], [:grace], [:reuse] or [:invalid].
  # The row lock serializes concurrent refreshes of the same token.
  def rotate!
    self.class.with_family_lock(family_id) do
      with_lock do
        if revoked? || expired?
          [ :invalid ]
        elsif rotated_at.nil?
          update!(rotated_at: Time.current)
          retire_siblings
          issue_child
        elsif rotated_at > REUSE_GRACE.ago
          recoverable_replay? ? issue_child : [ :grace ]
        else
          revoke_family!
          [ :reuse ]
        end
      end
    end
  end

  def revoke_family!
    self.class.with_family_lock(family_id) do
      self.class.where(family_id: family_id, revoked_at: nil).update_all(revoked_at: Time.current)
    end
  end

  def expired?
    expires_at <= Time.current
  end

  def revoked?
    revoked_at.present?
  end

  private

  def issue_child
    raw_token, child = self.class.issue(user: user, family_id: family_id, absolute_expires_at: absolute_expires_at, parent: self)
    [ :rotated, raw_token, child ]
  end

  # A response was only lost if this token rotated on its own and no child has been used since.
  # A used (or retired) child means the browser already holds a live token, so another sibling would fork the chain.
  def recoverable_replay?
    children.count.between?(1, MAX_SIBLINGS - 1) && children.where.not(rotated_at: nil).none?
  end

  def retire_siblings
    return unless parent_id

    self.class.where(parent_id: parent_id, rotated_at: nil).where.not(id: id).update_all(rotated_at: Time.current)
  end
end
