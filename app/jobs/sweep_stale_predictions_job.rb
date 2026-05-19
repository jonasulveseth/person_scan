class SweepStalePredictionsJob < ApplicationJob
  queue_as :default

  # Visitors must have been quiet for at least this long before we
  # re-classify — keeps us from re-running mid-session.
  QUIET_PERIOD = 2.minutes

  # Visitors that haven't been seen within this window are intentionally
  # frozen — no point re-classifying someone who hasn't come back.
  ACTIVITY_LOOKBACK = 7.days

  # Minimum NEW events since the latest prediction before re-classifying.
  # For visitors without any prediction yet, this is the minimum total.
  MIN_NEW_EVENTS = 3

  # Hard cap per run — bounds the LLM bill from runaway traffic spikes.
  MAX_VISITORS_PER_RUN = 200

  def perform
    window = (Time.current - ACTIVITY_LOOKBACK)..(QUIET_PERIOD.ago)
    scope = Visitor.where(last_seen_at: window)

    enqueued = 0
    skipped_session = 0
    skipped_thin    = 0

    scope.find_each(batch_size: 200) do |visitor|
      break if enqueued >= MAX_VISITORS_PER_RUN

      reason = stale_kind_reason(visitor)
      case reason
      when :session then skipped_session += 1; next
      when :thin    then skipped_thin    += 1; next
      end

      ClassifyVisitorJob.perform_later(visitor.id)
      enqueued += 1
    end

    Rails.logger.info "[sweep-stale-predictions] enqueued=#{enqueued} " \
                      "skipped_session=#{skipped_session} skipped_thin=#{skipped_thin}"
  end

  private

  # Returns nil if at least one kind is eligible to be re-classified,
  # otherwise :session (no activity since last prediction in every kind)
  # or :thin (too few new events for any kind).
  def stale_kind_reason(visitor)
    worst = :session
    ModelConfig::KINDS.each do |kind|
      kind_pred_at = visitor.predictions
                            .joins(:model_config).where(model_configs: { kind: kind })
                            .maximum(:created_at)
      if kind_pred_at && visitor.last_seen_at <= kind_pred_at
        next # this kind is fresh; check the others
      end
      since = kind_pred_at || Time.at(0)
      if event_count_since(visitor, since) >= MIN_NEW_EVENTS
        return nil
      else
        worst = :thin
      end
    end
    worst
  end

  def event_count_since(visitor, since)
    visitor.tracking_events.where("created_at > ?", since).count +
      visitor.click_events.where("created_at > ?", since).count +
      visitor.page_visits.where("created_at > ?", since).count
  end
end
