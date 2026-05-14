require "sqlite3"

# Imports labeled visitors from a legacy person_scan SQLite (Rails 4 era).
# Produces TrainingExample rows with ground_truth = {gender, age_bracket}.
#
# Usage:
#   LegacyImporter.call("/path/to/development.sqlite3")
class LegacyImporter
  SOURCE = "legacy_import"

  AGE_MAP = {
    "10-20" => "10-20", "20-30" => "20-30", "30-40" => "30-40",
    "40-50" => "40-50", "50-60" => "50-60", "60-70" => "60-70",
    "70-80" => "70+",   "80-90" => "70+",
    # Older rows sometimes used short forms; keep as-is.
    "10" => "10-20", "20" => "20-30", "30" => "30-40", "40" => "40-50",
    "50" => "50-60", "60" => "60-70", "70" => "70+"
  }.freeze

  Result = Struct.new(:imported, :skipped, :updated, :errors, keyword_init: true)

  def self.call(path) = new(path).call

  def initialize(path)
    @path = path
    @db = SQLite3::Database.new(path)
    @db.results_as_hash = true
  end

  def call
    imported = 0
    skipped  = 0
    updated  = 0
    errors   = []

    labeled = @db.execute(<<~SQL)
      SELECT id, cookie_id, male, age_sector
      FROM users
      WHERE age_sector IS NOT NULL AND age_sector <> '?'
    SQL

    labeled.each do |u|
      cookie = u["cookie_id"]
      next if cookie.blank?

      gender = case u["male"]
               when 1, "t", true then "male"
               when 0, "f", false then "female"
               else "unknown"
               end
      age_bracket = AGE_MAP[u["age_sector"].to_s] || u["age_sector"].to_s
      ground_truth = { "gender" => gender, "age_bracket" => age_bracket }

      features = build_features(cookie)
      next (skipped += 1) if features[:counts][:total_events].zero?

      existing = TrainingExample.find_by(legacy_cookie_id: cookie)
      if existing
        existing.update!(features: features, ground_truth: ground_truth)
        updated += 1
      else
        TrainingExample.create!(
          source: SOURCE,
          legacy_cookie_id: cookie,
          features: features,
          ground_truth: ground_truth,
          notes: "Imported from #{File.basename(@path)} user_id=#{u["id"]}"
        )
        imported += 1
      end
    rescue => e
      errors << "user_id=#{u["id"]}: #{e.message}"
    end

    Result.new(imported: imported, skipped: skipped, updated: updated, errors: errors)
  ensure
    @db&.close
  end

  private

  def build_features(cookie)
    basic = @db.execute("SELECT * FROM basic_data WHERE cookie_id = ? ORDER BY id DESC LIMIT 1", [cookie]).first
    advanced = @db.execute("SELECT * FROM advanced_data WHERE cookie_id = ? ORDER BY id DESC LIMIT 1", [cookie]).first
    clicks = @db.execute("SELECT * FROM link_clicks WHERE cookie_id = ?", [cookie])

    overtimes = clicks.map { |c| Float(c["overtime"], exception: false) }.compact
    accelerations = clicks.flat_map { |c| Array(c["mouse_acceleration"]&.split(",")).map { |v| Float(v, exception: false) } }.compact
    speeds        = clicks.flat_map { |c| Array(c["mouse_speed"]&.split(",")).map { |v| Float(v, exception: false) } }.compact

    {
      session: {
        device_width:  basic&.dig("device_width"),
        device_height: basic&.dig("device_height"),
        browser:       basic&.dig("browser"),
        operating_system: basic&.dig("operating_system"),
        hardware:      basic&.dig("hardware"),
        city:          basic&.dig("city"),
        country:       basic&.dig("country"),
        weekday:       basic&.dig("weekday"),
        time_of_visit: basic&.dig("time_of_visit"),
        modern_browser: basic&.dig("modern_browser")
      }.compact,
      counts: {
        click_events: clicks.size,
        total_events: clicks.size + (basic ? 1 : 0)
      },
      legacy_advanced: advanced ? {
        tone: advanced["tone"],
        scroll_tempo: advanced["scroll_tempo"],
        clicks_in_1_minute: advanced["clicks_in_1_minute"],
        mouse_down_up_time: advanced["mouse_down_up_time"],
        mouse_stop_to_click: advanced["mouse_stop_to_click"],
        open_close_time: advanced["open_close_time"]
      }.compact : {},
      clicks: {
        count: clicks.size,
        link_overtime_ms: summarize(overtimes),
        speed: summarize(speeds),
        acceleration: summarize(accelerations)
      }
    }
  end

  def summarize(values)
    return { count: 0 } if values.empty?
    s = values.sort
    {
      count: values.size,
      min:   s.first.round(2),
      max:   s.last.round(2),
      median: percentile(s, 0.5).round(2),
      mean:  (values.sum / values.size).round(2)
    }
  end

  def percentile(sorted, p)
    return 0.0 if sorted.empty?
    idx = (p * (sorted.size - 1))
    lower = sorted[idx.floor]
    upper = sorted[idx.ceil]
    lower + (upper - lower) * (idx - idx.floor)
  end
end
