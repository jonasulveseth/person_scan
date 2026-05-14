module Llm
  class Error < StandardError; end
  class ConfigError < Error; end
  class ApiError < Error; end

  # Result returned from every provider's #classify call.
  Result = Struct.new(:label, :dimensions, :confidence, :rationale, :raw, keyword_init: true)

  class Provider
    # Pick the right adapter for a ModelConfig.
    def self.for(model_config)
      case model_config.provider
      when "nebius"    then Llm::Nebius.new(model_config)
      when "anthropic" then raise ConfigError, "Anthropic provider not implemented yet"
      when "openai"    then raise ConfigError, "OpenAI provider not implemented yet"
      when "google"    then raise ConfigError, "Google provider not implemented yet"
      else raise ConfigError, "Unknown provider: #{model_config.provider.inspect}"
      end
    end

    def initialize(model_config)
      @config = model_config
    end

    # Subclasses must implement #classify(features_json) returning a Result.
    def classify(_features_json)
      raise NotImplementedError
    end

    protected

    # Parse a Result out of an LLM's JSON response body (the model's text output).
    # Tolerates code-fenced JSON.
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
