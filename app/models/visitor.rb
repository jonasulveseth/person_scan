class Visitor < ApplicationRecord
  belongs_to :site
  has_many :page_visits, dependent: :destroy
  has_many :click_events, dependent: :destroy
  has_many :tracking_events, dependent: :destroy
end
