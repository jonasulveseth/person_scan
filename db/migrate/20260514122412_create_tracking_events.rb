class CreateTrackingEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :tracking_events do |t|
      t.references :visitor, null: false, foreign_key: true
      t.references :site, null: false, foreign_key: true
      t.integer :decisive_scroll
      t.integer :indecisive_scroll
      t.integer :mouse_moving
      t.integer :mouse_still
      t.jsonb :mouse_data
      t.jsonb :click_times
      t.jsonb :orientation_beta
      t.jsonb :orientation_gamma
      t.text :link_positions
      t.text :link_overtimes
      t.boolean :adblock

      t.timestamps
    end
  end
end
