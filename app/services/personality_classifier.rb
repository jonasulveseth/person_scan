class PersonalityClassifier
  MIN_EVENTS = 1 # MVP: try as soon as we have anything; tune later.

  def self.call(visitor) = new(visitor).call

  def initialize(visitor)
    @visitor = visitor
  end

  def call
    config = ModelConfig.default
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
      raw: { rationale: result.rationale, response: result.raw }
    )
  end

  private

  def enough_data?
    @visitor.tracking_events.exists? || @visitor.click_events.exists? || @visitor.page_visits.exists?
  end
end
