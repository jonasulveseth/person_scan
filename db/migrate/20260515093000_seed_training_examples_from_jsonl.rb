require "json"

# Loads the bundled training_examples.jsonl into the database. Idempotent:
# rows with an existing legacy_cookie_id are skipped (we never overwrite
# data the user may have refined on the target environment).
class SeedTrainingExamplesFromJsonl < ActiveRecord::Migration[8.0]
  DATA_FILE = Rails.root.join("db/seed_data/training_examples.jsonl")
  BATCH     = 500

  def up
    unless File.exist?(DATA_FILE)
      say "Skipping: #{DATA_FILE} not present", true
      return
    end

    existing_keys = ActiveRecord::Base.connection
      .select_values("SELECT legacy_cookie_id FROM training_examples WHERE legacy_cookie_id IS NOT NULL")
      .to_set

    now      = Time.current
    inserted = 0
    skipped  = 0
    buffer   = []

    File.foreach(DATA_FILE) do |line|
      row = JSON.parse(line)
      key = row["legacy_cookie_id"]

      if key && existing_keys.include?(key)
        skipped += 1
        next
      end
      existing_keys << key if key

      buffer << {
        legacy_cookie_id: key,
        source:           row["source"],
        features:         row["features"].to_json,
        ground_truth:     row["ground_truth"].to_json,
        notes:            row["notes"],
        created_at:       row["created_at"] || now,
        updated_at:       row["updated_at"] || now
      }

      if buffer.size >= BATCH
        inserted += flush(buffer)
        buffer.clear
      end
    end

    inserted += flush(buffer) if buffer.any?
    say "Training examples: #{inserted} inserted, #{skipped} skipped (already present)", true
  end

  def down
    # No-op: we don't want a rollback to wipe training data, which may
    # have been hand-curated on top of the seeded rows.
    say "Down migration is a no-op (training data is not destroyed on rollback)"
  end

  private

  def flush(rows)
    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.send(:sanitize_sql_array, [
        "INSERT INTO training_examples (legacy_cookie_id, source, features, ground_truth, notes, created_at, updated_at) " \
        "VALUES #{(["(?, ?, ?::jsonb, ?::jsonb, ?, ?, ?)"] * rows.size).join(", ")}",
        *rows.flat_map { |r| [r[:legacy_cookie_id], r[:source], r[:features], r[:ground_truth], r[:notes], r[:created_at], r[:updated_at]] }
      ])
    )
    rows.size
  end
end
