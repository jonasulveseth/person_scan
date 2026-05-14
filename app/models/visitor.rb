class Visitor < ApplicationRecord
  belongs_to :site
  has_many :page_visits, dependent: :destroy
  has_many :click_events, dependent: :destroy
  has_many :tracking_events, dependent: :destroy

  has_one  :visitor_feature, dependent: :destroy
  has_many :predictions, dependent: :destroy

  def latest_prediction
    predictions.order(created_at: :desc).first
  end
end
