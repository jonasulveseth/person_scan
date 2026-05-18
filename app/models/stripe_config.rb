class StripeConfig
  MODES = %w[test live].freeze

  class << self
    def mode
      Rails.application.credentials.dig(:stripe, :mode)&.to_s.presence || "test"
    end

    def test?
      mode == "test"
    end

    def live?
      mode == "live"
    end

    def secret_key
      Rails.application.credentials.dig(:stripe, mode.to_sym, :secret_key)
    end

    def publishable_key
      Rails.application.credentials.dig(:stripe, mode.to_sym, :publishable_key)
    end

    def webhook_secret
      Rails.application.credentials.dig(:stripe, mode.to_sym, :webhook_secret)
    end

    def price_id(plan)
      Rails.application.credentials.dig(:stripe, mode.to_sym, :prices, plan.to_sym)
    end

    def configured?
      secret_key.present? && publishable_key.present?
    end
  end
end
