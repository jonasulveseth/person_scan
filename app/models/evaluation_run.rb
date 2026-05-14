class EvaluationRun < ApplicationRecord
  belongs_to :model_config

  def accuracy_gender
    return nil if total.to_i.zero?
    correct_gender.to_f / total
  end

  def accuracy_age_bracket
    return nil if total.to_i.zero?
    correct_age_bracket.to_f / total
  end

  def finished? = finished_at.present?
end
