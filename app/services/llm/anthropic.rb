require "net/http"
require "uri"
require "json"

module Llm
  class Anthropic < Provider
    ENDPOINT = URI("https://api.anthropic.com/v1/messages")
    API_VERSION = "2023-06-01"
    MAX_TOKENS = 1024
    READ_TIMEOUT = 60

    def self.api_key_present?
      Rails.application.credentials.dig(:anthropic, :api_key).present?
    end

    def classify(features_json)
      key = Rails.application.credentials.dig(:anthropic, :api_key)
      raise ConfigError, "Anthropic API key not set" if key.blank?

      body = {
        model: @config.model_id,
        max_tokens: MAX_TOKENS,
        system: [
          { type: "text", text: @config.prompt_template, cache_control: { type: "ephemeral" } }
        ],
        messages: [
          { role: "user", content: "Visitor features:\n```json\n#{features_json}\n```\n\nReturn only the JSON described in the system prompt." }
        ]
      }

      http = Net::HTTP.new(ENDPOINT.host, ENDPOINT.port)
      http.use_ssl = true
      http.read_timeout = READ_TIMEOUT
      req = Net::HTTP::Post.new(ENDPOINT.path, {
        "x-api-key"         => key,
        "anthropic-version" => API_VERSION,
        "content-type"      => "application/json"
      })
      req.body = body.to_json

      res = http.request(req)
      raise ApiError, "Anthropic #{res.code}: #{res.body.to_s[0, 500]}" unless res.is_a?(Net::HTTPSuccess)

      payload = JSON.parse(res.body)
      text = payload.dig("content", 0, "text").to_s
      parse_result(text, payload)
    end
  end
end
