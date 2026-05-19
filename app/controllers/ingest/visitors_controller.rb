module Ingest
  class VisitorsController < BaseController
    before_action :load_visitor, only: :track

    def new_session
      fp = params[:fingerprint_id].to_s
      head(:bad_request) and return if fp.blank?

      visitor = Visitor.find_or_initialize_by(site: @site, fingerprint: fp)
      visitor.first_seen_at ||= Time.current
      visitor.last_seen_at = Time.current

      assign_if_present(visitor, :device_width, params[:device_width])
      assign_if_present(visitor, :device_height, params[:device_height])
      assign_if_present(visitor, :window_width, params[:window_width])
      assign_if_present(visitor, :window_height, params[:window_height])
      assign_if_present(visitor, :color_depth, params[:color_depth])
      assign_if_present(visitor, :timezone_offset, params[:timezone_offset])
      assign_if_present(visitor, :history_length, params[:history_length])
      assign_if_present(visitor, :hardware_concurrency, params[:hardware_concurrency])
      assign_if_present(visitor, :browser_language, params[:browser_language])
      assign_if_present(visitor, :referrer, params[:referrer])
      assign_if_present(visitor, :cookies_enabled, to_bool(params[:cookies_enabled]))
      assign_if_present(visitor, :training_age, params[:age])
      assign_if_present(visitor, :training_gender, params[:gender])
      visitor.save!

      render json: { ok: true, visitor_id: visitor.id }
    end

    def track
      payload = params.permit!.to_h.except(:controller, :action, :site_id, :fingerprint_id, :format)

      if (adblock = params[:adblock]) && @visitor.adblock.nil?
        @visitor.update_column(:adblock, to_bool(adblock))
      end

      TrackingEvent.create!(
        visitor: @visitor,
        site: @site,
        decisive_scroll: payload["decisive_scroll"],
        indecisive_scroll: payload["indecisive_scroll"],
        mouse_moving: payload["mouse_moving"],
        mouse_still: payload["mouse_still"],
        mouse_data: extract_mouse_data(payload),
        click_times: parse_json_or_array(payload["clickTimes"]),
        orientation_beta: parse_json_or_array(payload["orientation_beta"]),
        orientation_gamma: parse_json_or_array(payload["orientation_gamma"]),
        link_positions: payload["link_positions"],
        link_overtimes: payload["link_overtimes"],
        adblock: to_bool(payload["adblock"]),
        time_to_first_move_ms: parse_int(payload["time_to_first_move_ms"])
      )

      enqueue_classification
      head :no_content
    end

    private

    def assign_if_present(record, attr, value)
      record[attr] = value unless value.nil? || value == ""
    end

    def to_bool(v)
      return nil if v.nil?
      ActiveModel::Type::Boolean.new.cast(v)
    end

    def parse_int(v)
      return nil if v.nil? || v == ""
      Integer(v)
    rescue ArgumentError, TypeError
      nil
    end

    def extract_mouse_data(payload)
      {
        directions: parse_json_or_array(payload["directions"]),
        curvatureAngles: parse_json_or_array(payload["curvatureAngles"]),
        curvatureDistances: parse_json_or_array(payload["curvatureDistances"]),
        speeds: parse_json_or_array(payload["speeds"]),
        accelerations: parse_json_or_array(payload["accelerations"])
      }
    end

    def parse_json_or_array(v)
      return [] if v.nil? || v == ""
      return v if v.is_a?(Array) || v.is_a?(Hash)
      JSON.parse(v.to_s)
    rescue JSON::ParserError
      v.to_s
    end
  end
end
