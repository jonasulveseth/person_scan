class Site < ApplicationRecord
  belongs_to :user
  belongs_to :model_config, optional: true

  has_many :visitors, dependent: :destroy

  def effective_model_config
    model_config || ModelConfig.default
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
