class ModelConfig < ApplicationRecord
  has_many :predictions, dependent: :restrict_with_error

  KINDS = %w[persona big5].freeze

  validates :name, :provider, :model_id, :prompt_template, presence: true
  validates :name, uniqueness: true
  validates :provider, inclusion: { in: %w[nebius anthropic openai google] }
  validates :kind, inclusion: { in: KINDS }

  scope :active, -> { where(active: true) }
  scope :for_kind, ->(k) { where(kind: k) }

  # The persona default. Kept for back-compat with old callers; prefer
  # default_for("persona") in new code.
  def self.default
    default_for("persona")
  end

  def self.default_for(kind)
    scope = active.for_kind(kind)
    scope.where(is_default: true).first || scope.first
  end

  before_save :enforce_single_default

  private

  # Default-flag is scoped per kind — each kind has its own default.
  def enforce_single_default
    return unless is_default? && (new_record? || is_default_changed? || kind_changed?)
    ModelConfig.where.not(id: id).where(kind: kind, is_default: true).update_all(is_default: false)
  end
end
