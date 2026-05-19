class Site < ApplicationRecord
  belongs_to :user
  belongs_to :model_config, optional: true

  has_many :visitors, dependent: :destroy
  has_many :api_keys, dependent: :destroy

  # Site-level override only applies to the site's "persona" model. Other
  # kinds (big5, future) always resolve to the system default for that kind.
  def effective_model_config(kind: "persona")
    if kind == "persona"
      model_config || ModelConfig.default_for("persona")
    else
      ModelConfig.default_for(kind)
    end
  end

  before_validation :assign_public_key, on: :create

  validates :name, presence: true
  validates :public_key, presence: true, uniqueness: true

  def to_param
    public_key
  end

  private

  def assign_public_key
    return if public_key.present?
    loop do
      candidate = SecureRandom.alphanumeric(16).downcase
      break self.public_key = candidate unless Site.exists?(public_key: candidate)
    end
  end
end
