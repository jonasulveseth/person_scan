module Llm
  class OpenAi < OpenAiCompatible
    def self.api_key_present?
      Rails.application.credentials.dig(:openai, :api_key).present?
    end

    private

    def endpoint_url = "https://api.openai.com/v1/chat/completions"
    def api_key      = Rails.application.credentials.dig(:openai, :api_key)
  end
end
