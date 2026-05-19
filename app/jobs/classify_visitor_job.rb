class ClassifyVisitorJob < ApplicationJob
  queue_as :default

  # Debounce per kind: don't re-classify a given (visitor, kind) more
  # often than this. Prevents one prediction per event.
  DEBOUNCE_SECONDS = 30

  # Retry transient API errors (rate limits, 5xx, network) — but NOT config
  # errors (no API key set), since those won't fix themselves.
  retry_on Llm::ApiError, wait: :polynomially_longer, attempts: 4
  discard_on Llm::ConfigError do |job, error|
    Rails.logger.warn "[classify-visitor] visitor=#{job.arguments.first} configuration issue, discarded: #{error.message}"
  end

  def perform(visitor_id)
    visitor = Visitor.find_by(id: visitor_id)
    return if visitor.nil?

    ModelConfig::KINDS.each do |kind|
      config = visitor.site.effective_model_config(kind: kind)
      next if config.nil?

      last = visitor.predictions
                    .joins(:model_config).where(model_configs: { kind: kind })
                    .maximum(:created_at)
      next if last.present? && last > DEBOUNCE_SECONDS.seconds.ago

      PersonalityClassifier.call(visitor, model_config: config)
    end
  end
end
