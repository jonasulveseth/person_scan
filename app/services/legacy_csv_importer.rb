require "csv"

# Imports pre-aggregated training data from the legacy app's CSV export
# (public/csv/gender.csv produced by old VisitorsController#training_data_csv).
#
# Each row already has aggregated features + ground truth labels.
class LegacyCsvImporter
  SOURCE = "legacy_csv"

  AGE_MAP = {
    "70-80" => "70+", "80-90" => "70+", "90-100" => "70+"
  }.freeze

  NULL_TOKENS = ["?", "undefined", "", nil].freeze

  Result = Struct.new(:imported, :updated, :skipped, :errors, keyword_init: true)

  def self.call(path) = new(path).call

  def initialize(path)
    @path = path
  end

  def call
    imported = updated = skipped = 0
    errors = []

    CSV.foreach(@path, headers: true) do |row|
      gender = clean(row["gender"])
      next (skipped += 1) if gender.blank? || gender == "?"

      age_raw = clean(row["age_sector"])
      age_bracket = age_raw.blank? || age_raw == "?" ? nil : (AGE_MAP[age_raw] || age_raw)

      ground_truth = { "gender" => gender, "age_bracket" => age_bracket }.compact
      next (skipped += 1) if ground_truth["gender"].blank?

      key = "legacy_csv_visitor_#{row["visitor_id"]}_site_#{row["site_id"]}"
      features = build_features(row)

      existing = TrainingExample.find_by(legacy_cookie_id: key)
      attrs = {
        source: SOURCE,
        legacy_cookie_id: key,
        features: features,
        ground_truth: ground_truth,
        notes: "Imported from #{File.basename(@path)} visitor_id=#{row["visitor_id"]} site_id=#{row["site_id"]}"
      }
      if existing
        existing.update!(attrs.except(:source))
        updated += 1
      else
        TrainingExample.create!(attrs)
        imported += 1
      end
    rescue => e
      errors << "row #{row["visitor_id"]}: #{e.message}"
    end

    Result.new(imported: imported, updated: updated, skipped: skipped, errors: errors)
  end

  private

  def clean(v)
    return nil if NULL_TOKENS.include?(v)
    v.to_s.strip
  end

  def num(v)
    Float(clean(v), exception: false)
  end

  def build_features(row)
    {
      session: {
        browser: clean(row["browser"]),
        time_of_visit: clean(row["time_of_visit"]),
        weekday: clean(row["weekday"]),
        country: clean(row["country"]),
        city: clean(row["city"]),
        hardware: clean(row["hardware"]),
        operating_system: clean(row["operating_system"]),
        device_width: num(row["device_width"]),
        device_height: num(row["device_height"]),
        browser_width: num(row["browser_width"]),
        browser_height: num(row["browser_height"]),
        modern_browser: clean(row["modern_browser"]),
        browser_version: clean(row["browser_version"]),
        history_length: num(row["history_length"]),
        browser_language: clean(row["browser_language"]),
        referrer: clean(row["referrer"]),
        color_depth: num(row["color_depth"]),
        hardware_concurrency: num(row["hardware_concurrency"]),
        cookies_enabled: clean(row["cookies_enabled"])
      }.compact,
      scroll: {
        decisiveness: num(row["scroll_decisiveness"])
      }.compact,
      mouse_activity: {
        activity_score: num(row["mouse_activity"])
      }.compact,
      mouse_motion: {
        favorite_direction: num(row["favorite_mouse_directon"]),
        favorite_curvature_angle: num(row["favorite_mouse_curvature_angle"]),
        favorite_curvature_distance: num(row["favorite_mouse_curvature_distance"]),
        mean_speed: num(row["mean_speed"]),
        stddev_speed: num(row["standard_deviation_speed"]),
        favorite_speed: num(row["favorite_speed"]),
        mean_acceleration: num(row["mean_acceleration"]),
        stddev_acceleration: num(row["standard_deviation_acceleration"]),
        favorite_acceleration: num(row["favorite_acceleration"]),
        median_end_acceleration: num(row["median_end_acceleration"]),
        deacceleration_time: num(row["deacceleration_time"])
      }.compact,
      clicks: {
        mean_click_time: num(row["mean_click_time"]),
        stddev_click_time: num(row["standard_deviation_click_time"]),
        favorite_click_time: num(row["favorite_click_time"]),
        median_overtime: num(row["median_overtime"])
      }.compact
    }
  end
end
