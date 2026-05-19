class Visitor < ApplicationRecord
  belongs_to :site
  has_many :page_visits, dependent: :destroy
  has_many :click_events, dependent: :destroy
  has_many :tracking_events, dependent: :destroy

  has_one  :visitor_feature, dependent: :destroy
  has_many :predictions, dependent: :destroy

  def latest_prediction(kind: nil)
    scope = predictions.order(created_at: :desc)
    scope = scope.joins(:model_config).where(model_configs: { kind: kind }) if kind
    scope.first
  end
end
