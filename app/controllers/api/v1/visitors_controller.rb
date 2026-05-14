module Api
  module V1
    class VisitorsController < BaseController
      MAX_PAGE_SIZE = 100

      def index
        page = [params[:page].to_i, 1].max
        per_page = [[params[:per_page].to_i, 1].max, MAX_PAGE_SIZE].min
        per_page = 20 if per_page.zero?

        scope = @site.visitors.order(last_seen_at: :desc)
        total = scope.count
        records = scope.offset((page - 1) * per_page).limit(per_page).includes(:predictions)

        render json: {
          page: page,
          per_page: per_page,
          total: total,
          total_pages: (total.to_f / per_page).ceil,
          visitors: records.map { |v| visitor_summary(v) }
        }
      end

      def show
        visitor = @site.visitors.find_by(fingerprint: params[:fingerprint])
        unless visitor
          render json: { error: "not_found" }, status: :not_found
          return
        end
        render json: visitor_detail(visitor)
      end

      private

      def visitor_summary(v)
        pred = v.predictions.max_by(&:created_at)
        {
          fingerprint: v.fingerprint,
          first_seen_at: v.first_seen_at,
          last_seen_at: v.last_seen_at,
          prediction: pred && {
            label: pred.label,
            confidence: pred.confidence,
            dimensions: pred.dimensions,
            model: pred.model_config.name,
            created_at: pred.created_at
          }
        }
      end

      def visitor_detail(v)
        feature = v.visitor_feature
        pred = v.predictions.order(created_at: :desc).first
        {
          fingerprint: v.fingerprint,
          first_seen_at: v.first_seen_at,
          last_seen_at: v.last_seen_at,
          session: {
            device_width: v.device_width,
            device_height: v.device_height,
            browser_language: v.browser_language,
            timezone_offset: v.timezone_offset,
            referrer: v.referrer,
            adblock: v.adblock,
            cookies_enabled: v.cookies_enabled
          },
          counts: {
            tracking_events: v.tracking_events.count,
            click_events:    v.click_events.count,
            page_visits:     v.page_visits.count
          },
          features: feature&.features || {},
          prediction: pred && {
            label: pred.label,
            confidence: pred.confidence,
            dimensions: pred.dimensions,
            rationale: pred.raw.is_a?(Hash) ? pred.raw["rationale"] : nil,
            model: pred.model_config.name,
            created_at: pred.created_at
          }
        }
      end
    end
  end
end
