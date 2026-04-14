# frozen_string_literal: true

class RefreshToken < ApplicationRecord
  EXPIRATION = 7.days
  TOKEN_LENGTH = 32

  belongs_to :user

  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }

  def self.generate_for(user)
    raw_token = SecureRandom.urlsafe_base64(TOKEN_LENGTH)
    refresh_token = create!(
      user: user,
      token_digest: Digest::SHA256.hexdigest(raw_token),
      expires_at: EXPIRATION.from_now
    )
    [ raw_token, refresh_token ]
  end

  def self.find_by_raw_token(raw_token)
    return nil if raw_token.blank?

    digest = Digest::SHA256.hexdigest(raw_token)
    active.find_by(token_digest: digest)
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def expired?
    expires_at <= Time.current
  end

  def revoked?
    revoked_at.present?
  end
end
