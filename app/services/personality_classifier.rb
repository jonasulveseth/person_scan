class PersonalityClassifier
  MIN_EVENTS = 1 # MVP: try as soon as we have anything; tune later.

  def self.call(visitor, model_config: nil) = new(visitor, model_config: model_config).call

  def initialize(visitor, model_config: nil)
    @visitor = visitor
    @explicit_config = model_config
  end

  def call
    config = @explicit_config || @visitor.site.effective_model_config
    raise Llm::ConfigError, "No active ModelConfig" if config.nil?
    return nil unless enough_data?

    feature = FeatureAggregator.call(@visitor)
    result = Llm::Provider.for(config).classify(feature.features.to_json)

    Prediction.create!(
      visitor: @visitor,
      model_config: config,
      label: result.label,
      dimensions: result.dimensions,
      confidence: result.confidence,
      raw: {
        rationale: result.rationale,
        response: result.raw,
        confidences: result.confidences
      }
    )
  end

  private

  def enough_data?
    @visitor.tracking_events.exists? || @visitor.click_events.exists? || @visitor.page_visits.exists?
  end
end
