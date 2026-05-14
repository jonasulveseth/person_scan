class ApiKey < ApplicationRecord
  belongs_to :site

  before_validation :assign_token, on: :create

  validates :name, :token, presence: true
  validates :token, uniqueness: true

  scope :active, -> { where(active: true) }

  # Resolve a bearer token to its Site. Bumps last_used_at on hit.
  def self.authenticate(raw_token)
    return nil if raw_token.blank?
    key = active.find_by(token: raw_token)
    return nil unless key
    key.update_column(:last_used_at, Time.current)
    key.site
  end

  def masked
    "#{token[0, 6]}…#{token[-4, 4]}"
  end

  private

  def assign_token
    return if token.present?
    loop do
      candidate = "ps_" + SecureRandom.urlsafe_base64(32).tr("-_", "AB")
      break self.token = candidate unless ApiKey.exists?(token: candidate)
    end
  end
end
