class TrainingExample < ApplicationRecord
  belongs_to :visitor, optional: true

  validates :source, presence: true
  validates :ground_truth, presence: true

  SOURCES = %w[legacy_import manual visitor_label].freeze

  scope :for_eval, -> { where("ground_truth IS NOT NULL AND ground_truth::text <> '{}'") }

  def truth_gender = ground_truth["gender"]
  def truth_age_bracket = ground_truth["age_bracket"]
end
