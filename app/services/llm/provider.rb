module Llm
  class Error < StandardError; end
  class ConfigError < Error; end
  class ApiError < Error; end

  Result = Struct.new(:label, :dimensions, :confidence, :rationale, :raw, keyword_init: true)

  class Provider
    # Map provider key -> adapter class. Add new providers here.
    REGISTRY = {
      "nebius"    => "Llm::Nebius",
      "openai"    => "Llm::OpenAi",
      "anthropic" => "Llm::Anthropic"
    }.freeze

    def self.for(model_config)
      klass_name = REGISTRY[model_config.provider]
      raise ConfigError, "Unknown provider: #{model_config.provider.inspect}" if klass_name.nil?
      klass_name.constantize.new(model_config)
    end

    def self.provider_options
      REGISTRY.keys.map do |p|
        klass = REGISTRY[p].constantize
        [p, klass.respond_to?(:api_key_present?) && klass.api_key_present?]
      end
    end

    def initialize(model_config)
      @config = model_config
    end

    def classify(_features_json)
      raise NotImplementedError
    end

    protected

    def parse_result(text, raw_payload)
      cleaned = text.to_s.strip
                    .sub(/\A```(?:json)?\s*/i, "")
                    .sub(/```\s*\z/, "")
      data = JSON.parse(cleaned)
      Result.new(
        label: data["label"].to_s,
        dimensions: data["dimensions"] || {},
        confidence: Float(data["confidence"], exception: false) || 0.0,
        rationale: data["rationale"].to_s,
        raw: raw_payload
      )
    rescue JSON::ParserError => e
      raise ApiError, "LLM returned non-JSON response: #{e.message} | body: #{text.to_s[0, 500]}"
    end
  end
end
