class ModelConfig < ApplicationRecord
  has_many :predictions, dependent: :restrict_with_error

  validates :name, :provider, :model_id, :prompt_template, presence: true
  validates :name, uniqueness: true
  validates :provider, inclusion: { in: %w[nebius anthropic openai google] }

  scope :active, -> { where(active: true) }

  def self.default
    active.where(is_default: true).first || active.first
  end

  before_save :enforce_single_default

  private

  def enforce_single_default
    return unless is_default? && (new_record? || is_default_changed?)
    ModelConfig.where.not(id: id).where(is_default: true).update_all(is_default: false)
  end
end
