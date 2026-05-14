class ClassifyVisitorJob < ApplicationJob
  queue_as :default

  # Debounce: only run if at least DEBOUNCE_SECONDS have elapsed since the
  # last prediction for this visitor. Prevents one prediction per event.
  DEBOUNCE_SECONDS = 30

  def perform(visitor_id)
    visitor = Visitor.find_by(id: visitor_id)
    return if visitor.nil?

    last = visitor.predictions.order(created_at: :desc).limit(1).pick(:created_at)
    return if last.present? && last > DEBOUNCE_SECONDS.seconds.ago

    PersonalityClassifier.call(visitor)
  rescue Llm::Error => e
    Rails.logger.warn "[classify-visitor] visitor=#{visitor_id} #{e.class}: #{e.message}"
    raise if Rails.env.test?
  end
end
