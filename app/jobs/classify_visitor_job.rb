class ClassifyVisitorJob < ApplicationJob
  queue_as :default

  # Debounce: only run if at least DEBOUNCE_SECONDS have elapsed since the
  # last prediction for this visitor. Prevents one prediction per event.
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

    last = visitor.predictions.order(created_at: :desc).limit(1).pick(:created_at)
    return if last.present? && last > DEBOUNCE_SECONDS.seconds.ago

    PersonalityClassifier.call(visitor)
  end
end
