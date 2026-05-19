class FeatureAggregator
  def self.call(visitor) = new(visitor).call

  def initialize(visitor)
    @visitor = visitor
    @tracking_events = visitor.tracking_events.to_a
    @click_events    = visitor.click_events.to_a
    @page_visits     = visitor.page_visits.to_a
  end

  def call
    features = {
      session: session_features,
      familiarity: familiarity_features,
      counts: counts,
      scroll: scroll_features,
      mouse_activity: mouse_activity_features,
      mouse_motion: mouse_motion_features,
      clicks: click_features,
      pages: page_features
    }
    VisitorFeature.upsert(
      { visitor_id: @visitor.id, features: features, computed_at: Time.current,
        created_at: Time.current, updated_at: Time.current },
      unique_by: :index_visitor_features_on_visitor_id
    )
    @visitor.visitor_feature&.reload || @visitor.reload.visitor_feature
  end

  private

  def session_features
    v = @visitor
    {
      first_seen_at: v.first_seen_at&.iso8601,
      last_seen_at: v.last_seen_at&.iso8601,
      device_width: v.device_width,
      device_height: v.device_height,
      window_width: v.window_width,
      window_height: v.window_height,
      color_depth: v.color_depth,
      timezone_offset: v.timezone_offset,
      history_length: v.history_length,
      browser_language: v.browser_language,
      hardware_concurrency: v.hardware_concurrency,
      cookies_enabled: v.cookies_enabled,
      adblock: v.adblock,
      referrer: v.referrer,
      training_age: v.training_age,
      training_gender: v.training_gender,
      mobile_like: (v.device_width.to_i.positive? && v.device_width < 800)
    }.compact
  end

  # Tells the model whether fast/decisive behavior is likely familiarity
  # (returning visitor who knows the site) vs personality (new visitor
  # acting decisively from cold). Derived from existing data — no tracker
  # change needed.
  def familiarity_features
    first = @visitor.first_seen_at
    last  = @visitor.last_seen_at
    age_seconds = (first && last) ? (last - first).to_i : 0

    # Distinct calendar days with any activity — proxy for "how many
    # sessions across the site's lifetime".
    days = (
      @tracking_events.map { |e| e.created_at.to_date } +
      @click_events.map { |e| e.created_at.to_date } +
      @page_visits.map  { |e| e.created_at.to_date }
    ).uniq

    current_url = @page_visits.max_by(&:created_at)&.url
    visits_to_current_url = current_url ? @page_visits.count { |pv| pv.url == current_url } : 0

    # Time from page load to first purposeful mouse motion, in ms. One
    # observation per page load. Short values (<800ms) suggest a familiar
    # visitor with a target; long values (>2500ms) suggest cold orientation.
    first_move_values = @tracking_events.map(&:time_to_first_move_ms).compact
    first_move_first  = @tracking_events.sort_by(&:created_at).map(&:time_to_first_move_ms).compact.first
    first_move_summary = summarize(first_move_values)

    {
      visitor_age_seconds: age_seconds,
      visitor_age_days: (age_seconds / 86_400.0).round(2),
      distinct_active_days: days.size,
      is_returning: days.size > 1 || age_seconds > 3600,
      total_page_visits: @page_visits.size,
      distinct_urls_visited: @page_visits.map(&:url).compact.uniq.size,
      visits_to_current_url: visits_to_current_url,
      time_to_first_move_ms: {
        first_pageload: first_move_first,
        observations: first_move_summary
      }
    }
  end

  def counts
    {
      tracking_events: @tracking_events.size,
      click_events:    @click_events.size,
      page_visits:     @page_visits.size
    }
  end

  def scroll_features
    decisive   = @tracking_events.sum { |e| e.decisive_scroll.to_i }
    indecisive = @tracking_events.sum { |e| e.indecisive_scroll.to_i }
    total      = decisive + indecisive
    {
      decisive_count: decisive,
      indecisive_count: indecisive,
      decisive_ratio: ratio(decisive, total)
    }
  end

  def mouse_activity_features
    moving = @tracking_events.sum { |e| e.mouse_moving.to_i }
    still  = @tracking_events.sum { |e| e.mouse_still.to_i }
    total  = moving + still
    {
      moving: moving,
      still: still,
      activity_ratio: ratio(moving, total)
    }
  end

  def mouse_motion_features
    md = @tracking_events.map(&:mouse_data).compact

    {
      direction_samples:  flat_count(md, "directions"),
      curvature_angle:    summarize(flatten_nested(md, "curvatureAngles")),
      curvature_distance: summarize(flatten_nested(md, "curvatureDistances")),
      speed:              summarize(flatten_nested(md, "speeds")),
      acceleration:       summarize(flatten_nested(md, "accelerations")),
      acceleration_terminal: summarize(@click_events.map { |c| Array(c.mouse_acceleration).last }.compact),
      speed_terminal:        summarize(@click_events.map { |c| Array(c.mouse_speed).last }.compact)
    }
  end

  def click_features
    click_times = @tracking_events.flat_map { |e| Array(e.click_times) }.map(&:to_i).reject(&:zero?)
    overtimes   = @click_events.map(&:overtime).compact
    click_xs    = @click_events.map(&:click_x).compact
    click_ys    = @click_events.map(&:click_y).compact

    {
      count: @click_events.size,
      click_time_ms_x10: summarize(click_times),
      link_overtime_ms:  summarize(overtimes),
      click_x_pct:       summarize(click_xs),
      click_y_pct:       summarize(click_ys),
      median_overtime_boxed: boxin(median(overtimes), 0, 1000, 20)
    }
  end

  def page_features
    leaves   = @page_visits.select(&:leave)
    entries  = @page_visits.reject(&:leave)
    exit_click = leaves.count { |pv| pv.click_data.is_a?(Hash) && pv.click_data["element_href"].present? }
    {
      entries: entries.size,
      leaves: leaves.size,
      exit_click_count: exit_click,
      exit_click_rate: ratio(exit_click, leaves.size),
      distinct_urls: @page_visits.map(&:url).compact.uniq.size
    }
  end

  # ---------- helpers ----------

  def ratio(part, whole)
    return nil if whole.to_i.zero?
    (part.to_f / whole).round(4)
  end

  def flat_count(mouse_datas, key)
    mouse_datas.sum { |md| Array(md[key]).flatten.size }
  end

  def flatten_nested(mouse_datas, key)
    mouse_datas.flat_map { |md| Array(md[key]).flatten }.compact
  end

  def summarize(values)
    nums = values.map { |v| Float(v, exception: false) }.compact
    return { count: 0 } if nums.empty?
    sorted = nums.sort
    {
      count: nums.size,
      min: sorted.first.round(2),
      max: sorted.last.round(2),
      median: percentile(sorted, 0.5).round(2),
      p25: percentile(sorted, 0.25).round(2),
      p75: percentile(sorted, 0.75).round(2),
      mean: (nums.sum / nums.size).round(2),
      stddev: stddev(nums).round(2)
    }
  end

  def percentile(sorted, p)
    return 0.0 if sorted.empty?
    idx = (p * (sorted.size - 1))
    lower = sorted[idx.floor]
    upper = sorted[idx.ceil]
    lower + (upper - lower) * (idx - idx.floor)
  end

  def median(values)
    return nil if values.empty?
    s = values.sort
    s.length.odd? ? s[s.length / 2] : (s[s.length / 2 - 1] + s[s.length / 2]) / 2.0
  end

  def stddev(values)
    return 0.0 if values.size < 2
    mean = values.sum.to_f / values.size
    Math.sqrt(values.sum { |v| (v - mean)**2 } / (values.size - 1))
  end

  # Ported from legacy app/models/visitor.rb#boxin — discretize a value into N buckets
  def boxin(value, from, to, steps)
    return nil if value.nil?
    box_size = (to - from) / steps.to_f
    box = ((value - from) / box_size).floor
    [[steps, box].min, -1].max
  end
end
