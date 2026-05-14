class SiteTrends
  DAYS_BACK = 30

  def self.call(site) = new(site).call

  def initialize(site)
    @site = site
  end

  def call
    {
      generated_at: Time.current.iso8601,
      site: { id: @site.id, public_key: @site.public_key, name: @site.name },
      visitors: {
        total: visitor_scope.count,
        with_prediction: visitor_scope.joins(:predictions).distinct.count,
        new_last_30d: visitor_scope.where("first_seen_at >= ?", DAYS_BACK.days.ago).count
      },
      events: {
        tracking: TrackingEvent.where(site_id: @site.id).count,
        clicks:   ClickEvent.where(site_id: @site.id).count,
        page_visits: PageVisit.where(site_id: @site.id).count
      },
      predictions: {
        total: prediction_scope.count,
        avg_confidence: avg_confidence
      },
      distributions: {
        gender:      distribution_from_dim("likely_gender"),
        age_bracket: distribution_from_dim("likely_age_bracket"),
        label:       label_distribution(10)
      },
      avg_dimensions: avg_numeric_dimensions,
      time_series: time_series
    }
  end

  private

  def visitor_scope
    Visitor.where(site_id: @site.id)
  end

  def prediction_scope
    Prediction.joins(:visitor).where(visitors: { site_id: @site.id })
  end

  def avg_confidence
    avg = prediction_scope.average(:confidence)
    avg ? avg.to_f.round(3) : nil
  end

  def distribution_from_dim(key)
    sql = "dimensions->>'#{key}'"
    prediction_scope.group(Arel.sql(sql)).count.transform_keys { |k| k || "(none)" }
  end

  def label_distribution(top_n)
    prediction_scope.group(:label).order(Arel.sql("COUNT(*) DESC")).limit(top_n).count
  end

  def avg_numeric_dimensions
    %w[decisiveness impulsivity attentiveness engagement].each_with_object({}) do |dim, h|
      avg = prediction_scope.average(Arel.sql("(dimensions->>'#{dim}')::float"))
      h[dim] = avg ? avg.to_f.round(3) : nil
    end
  end

  def time_series
    series = prediction_scope
              .where("predictions.created_at >= ?", DAYS_BACK.days.ago)
              .group(Arel.sql("DATE(predictions.created_at)"))
              .count
    series.transform_keys(&:to_s).sort.to_h
  end
end
