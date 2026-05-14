require "net/http"
require "uri"
require "json"

module Llm
  # Base for providers that speak the OpenAI Chat Completions API
  # (OpenAI itself, Nebius, Together, Fireworks, vLLM, etc).
  # Subclasses set endpoint_url and api_key.
  class OpenAiCompatible < Provider
    MAX_TOKENS = 1024
    READ_TIMEOUT = 60

    def classify(features_json)
      key = api_key
      raise ConfigError, "#{self.class.name} API key not set" if key.blank?

      uri = URI(endpoint_url)
      body = {
        model: @config.model_id,
        max_tokens: MAX_TOKENS,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: @config.prompt_template },
          { role: "user",   content: "Visitor features:\n```json\n#{features_json}\n```\n\nReturn only the JSON described in the system prompt." }
        ]
      }

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.read_timeout = READ_TIMEOUT
      req = Net::HTTP::Post.new(uri.request_uri, {
        "Authorization" => "Bearer #{key}",
        "Content-Type"  => "application/json"
      })
      req.body = body.to_json

      res = http.request(req)
      raise ApiError, "#{self.class.name} #{res.code}: #{res.body.to_s[0, 500]}" unless res.is_a?(Net::HTTPSuccess)

      payload = JSON.parse(res.body)
      text = payload.dig("choices", 0, "message", "content").to_s
      parse_result(text, payload)
    end

    private

    # Subclasses override.
    def endpoint_url
      raise NotImplementedError
    end

    def api_key
      raise NotImplementedError
    end
  end
end
