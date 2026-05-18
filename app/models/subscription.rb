class Subscription < ApplicationRecord
  belongs_to :user

  validates :stripe_subscription_id, presence: true, uniqueness: true
  validates :plan, presence: true
  validates :status, presence: true
end
