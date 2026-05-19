# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_05_19_130000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "api_keys", force: :cascade do |t|
    t.bigint "site_id", null: false
    t.string "name", null: false
    t.string "token", null: false
    t.datetime "last_used_at"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["site_id"], name: "index_api_keys_on_site_id"
    t.index ["token"], name: "index_api_keys_on_token", unique: true
  end

  create_table "click_events", force: :cascade do |t|
    t.bigint "visitor_id", null: false
    t.bigint "site_id", null: false
    t.string "url"
    t.bigint "click_time"
    t.string "link_id"
    t.string "link_href"
    t.text "link_contents"
    t.integer "link_x"
    t.integer "link_y"
    t.integer "link_size"
    t.integer "click_x"
    t.integer "click_y"
    t.integer "overtime"
    t.jsonb "mouse_speed"
    t.jsonb "mouse_acceleration"
    t.string "text_analyze"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["site_id"], name: "index_click_events_on_site_id"
    t.index ["visitor_id"], name: "index_click_events_on_visitor_id"
  end

  create_table "evaluation_runs", force: :cascade do |t|
    t.bigint "model_config_id", null: false
    t.datetime "started_at"
    t.datetime "finished_at"
    t.integer "total"
    t.integer "correct_gender"
    t.integer "correct_age_bracket"
    t.float "avg_confidence"
    t.jsonb "results"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["model_config_id"], name: "index_evaluation_runs_on_model_config_id"
  end

  create_table "model_configs", force: :cascade do |t|
    t.string "name", null: false
    t.string "provider", null: false
    t.string "model_id", null: false
    t.text "prompt_template", null: false
    t.boolean "active", default: true, null: false
    t.boolean "is_default", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_default"], name: "index_model_configs_on_is_default", unique: true, where: "(is_default = true)"
    t.index ["name"], name: "index_model_configs_on_name", unique: true
  end

  create_table "page_visits", force: :cascade do |t|
    t.bigint "visitor_id", null: false
    t.bigint "site_id", null: false
    t.string "url"
    t.bigint "visit_time"
    t.boolean "leave"
    t.jsonb "click_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["site_id"], name: "index_page_visits_on_site_id"
    t.index ["visitor_id"], name: "index_page_visits_on_visitor_id"
  end

  create_table "predictions", force: :cascade do |t|
    t.bigint "visitor_id", null: false
    t.bigint "model_config_id", null: false
    t.jsonb "dimensions"
    t.string "label"
    t.float "confidence"
    t.jsonb "raw"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["model_config_id"], name: "index_predictions_on_model_config_id"
    t.index ["visitor_id"], name: "index_predictions_on_visitor_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "sites", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.string "url"
    t.string "public_key", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "model_config_id"
    t.index ["model_config_id"], name: "index_sites_on_model_config_id"
    t.index ["public_key"], name: "index_sites_on_public_key", unique: true
    t.index ["user_id"], name: "index_sites_on_user_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "stripe_subscription_id", null: false
    t.string "stripe_price_id"
    t.string "plan", null: false
    t.string "status", null: false
    t.datetime "trial_ends_at"
    t.datetime "current_period_end"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["stripe_subscription_id"], name: "index_subscriptions_on_stripe_subscription_id", unique: true
    t.index ["user_id"], name: "index_subscriptions_on_user_id"
  end

  create_table "tracking_events", force: :cascade do |t|
    t.bigint "visitor_id", null: false
    t.bigint "site_id", null: false
    t.integer "decisive_scroll"
    t.integer "indecisive_scroll"
    t.integer "mouse_moving"
    t.integer "mouse_still"
    t.jsonb "mouse_data"
    t.jsonb "click_times"
    t.jsonb "orientation_beta"
    t.jsonb "orientation_gamma"
    t.text "link_positions"
    t.text "link_overtimes"
    t.boolean "adblock"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "time_to_first_move_ms"
    t.index ["site_id"], name: "index_tracking_events_on_site_id"
    t.index ["visitor_id"], name: "index_tracking_events_on_visitor_id"
  end

  create_table "training_examples", force: :cascade do |t|
    t.jsonb "features", default: {}, null: false
    t.jsonb "ground_truth", default: {}, null: false
    t.string "source", null: false
    t.text "notes"
    t.bigint "visitor_id"
    t.string "legacy_cookie_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["legacy_cookie_id"], name: "index_training_examples_on_legacy_cookie_id"
    t.index ["source"], name: "index_training_examples_on_source"
    t.index ["visitor_id"], name: "index_training_examples_on_visitor_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "stripe_customer_id"
    t.string "plan", default: "free", null: false
    t.datetime "trial_ends_at"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["stripe_customer_id"], name: "index_users_on_stripe_customer_id", unique: true, where: "(stripe_customer_id IS NOT NULL)"
  end

  create_table "visitor_features", force: :cascade do |t|
    t.bigint "visitor_id", null: false
    t.jsonb "features", default: {}, null: false
    t.datetime "computed_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["visitor_id"], name: "index_visitor_features_on_visitor_id", unique: true
  end

  create_table "visitors", force: :cascade do |t|
    t.bigint "site_id", null: false
    t.string "fingerprint", null: false
    t.datetime "first_seen_at"
    t.datetime "last_seen_at"
    t.integer "device_width"
    t.integer "device_height"
    t.integer "window_width"
    t.integer "window_height"
    t.integer "color_depth"
    t.integer "timezone_offset"
    t.integer "history_length"
    t.string "browser_language"
    t.integer "hardware_concurrency"
    t.boolean "cookies_enabled"
    t.boolean "adblock"
    t.string "referrer"
    t.string "training_age"
    t.string "training_gender"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["site_id", "fingerprint"], name: "index_visitors_on_site_id_and_fingerprint", unique: true
    t.index ["site_id"], name: "index_visitors_on_site_id"
  end

  add_foreign_key "api_keys", "sites"
  add_foreign_key "click_events", "sites"
  add_foreign_key "click_events", "visitors"
  add_foreign_key "evaluation_runs", "model_configs"
  add_foreign_key "page_visits", "sites"
  add_foreign_key "page_visits", "visitors"
  add_foreign_key "predictions", "model_configs"
  add_foreign_key "predictions", "visitors"
  add_foreign_key "sessions", "users"
  add_foreign_key "sites", "model_configs"
  add_foreign_key "sites", "users"
  add_foreign_key "subscriptions", "users"
  add_foreign_key "tracking_events", "sites"
  add_foreign_key "tracking_events", "visitors"
  add_foreign_key "training_examples", "visitors"
  add_foreign_key "visitor_features", "visitors"
  add_foreign_key "visitors", "sites"
end
