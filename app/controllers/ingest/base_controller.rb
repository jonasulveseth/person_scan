module Ingest
  class BaseController < ActionController::API
    before_action :set_cors_headers
    before_action :load_site

    def options
      head :no_content
    end

    private

    def load_site
      key = params[:site_id].to_s
      @site = Site.find_by(public_key: key, active: true)
      head(:not_found) and return unless @site
    end

    def load_visitor
      fp = params[:fingerprint_id].to_s
      head(:bad_request) and return if fp.blank?
      @visitor = Visitor.find_or_create_by!(site: @site, fingerprint: fp) do |v|
        v.first_seen_at = Time.current
      end
      @visitor.update_column(:last_seen_at, Time.current)
    end

    def set_cors_headers
      response.headers["Access-Control-Allow-Origin"] = request.headers["Origin"] || "*"
      response.headers["Access-Control-Allow-Methods"] = "POST, OPTIONS"
      response.headers["Access-Control-Allow-Headers"] = "Content-Type"
      response.headers["Access-Control-Max-Age"] = "86400"
    end
  end
end
