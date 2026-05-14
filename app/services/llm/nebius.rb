module Llm
  class Nebius < OpenAiCompatible
    def self.api_key_present?
      Rails.application.credentials.dig(:nebius, :api_key).present?
    end

    private

    def endpoint_url = "https://api.studio.nebius.com/v1/chat/completions"
    def api_key      = Rails.application.credentials.dig(:nebius, :api_key)
  end
end
