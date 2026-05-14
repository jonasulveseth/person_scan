module Api
  module V1
    class BaseController < ActionController::API
      before_action :authenticate_api_key!

      private

      def authenticate_api_key!
        token = bearer_token
        @site = ApiKey.authenticate(token)
        render json: { error: "unauthorized" }, status: :unauthorized and return unless @site
      end

      def bearer_token
        header = request.headers["Authorization"].to_s
        return nil unless header.start_with?("Bearer ")
        header.sub(/^Bearer\s+/, "").strip
      end
    end
  end
end
