module Api
  module V1
    class SiteController < BaseController
      def show
        render json: {
          site: { id: @site.public_key, name: @site.name, url: @site.url },
          model: {
            name: @site.effective_model_config&.name,
            provider: @site.effective_model_config&.provider,
            model_id: @site.effective_model_config&.model_id
          },
          trends: SiteTrends.call(@site)
        }
      end
    end
  end
end
