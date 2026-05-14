class CreateVisitors < ActiveRecord::Migration[8.0]
  def change
    create_table :visitors do |t|
      t.references :site, null: false, foreign_key: true
      t.string :fingerprint, null: false
      t.datetime :first_seen_at
      t.datetime :last_seen_at
      t.integer :device_width
      t.integer :device_height
      t.integer :window_width
      t.integer :window_height
      t.integer :color_depth
      t.integer :timezone_offset
      t.integer :history_length
      t.string :browser_language
      t.integer :hardware_concurrency
      t.boolean :cookies_enabled
      t.boolean :adblock
      t.string :referrer
      t.string :training_age
      t.string :training_gender

      t.timestamps
    end
    add_index :visitors, [:site_id, :fingerprint], unique: true
  end
end
