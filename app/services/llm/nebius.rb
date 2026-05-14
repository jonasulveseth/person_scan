require "net/http"
require "uri"
require "json"

module Llm
  class Nebius < Provider
    ENDPOINT = URI("https://api.studio.nebius.com/v1/chat/completions")
    MAX_TOKENS = 1024

    def classify(features_json)
      api_key = Rails.application.credentials.dig(:nebius, :api_key)
      raise ConfigError, "Nebius API key not set (credentials :nebius :api_key)" if api_key.blank?

      body = {
        model: @config.model_id,
        max_tokens: MAX_TOKENS,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: @config.prompt_template },
          { role: "user",   content: "Visitor features:\n```json\n#{features_json}\n```\n\nReturn only the JSON described in the system prompt." }
        ]
      }

      http = Net::HTTP.new(ENDPOINT.host, ENDPOINT.port)
      http.use_ssl = true
      http.read_timeout = 60
      req = Net::HTTP::Post.new(ENDPOINT.path, {
        "Authorization" => "Bearer #{api_key}",
        "Content-Type"  => "application/json"
      })
      req.body = body.to_json

      res = http.request(req)
      raise ApiError, "Nebius #{res.code}: #{res.body.to_s[0, 500]}" unless res.is_a?(Net::HTTPSuccess)

      payload = JSON.parse(res.body)
      text = payload.dig("choices", 0, "message", "content").to_s
      parse_result(text, payload)
    end
  end
end
