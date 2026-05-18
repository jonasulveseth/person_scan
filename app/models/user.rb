class User < ApplicationRecord
  PLANS = %w[free starter growth scale].freeze

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :sites, dependent: :destroy
  has_many :subscriptions, dependent: :destroy

  validates :plan, inclusion: { in: PLANS }
  normalizes :email_address, with: ->(e) { e.strip.downcase }

  def active_subscription
    subscriptions.where(status: %w[active trialing]).order(created_at: :desc).first
  end

  def on_paid_plan?
    plan != "free" && active_subscription.present?
  end
end
