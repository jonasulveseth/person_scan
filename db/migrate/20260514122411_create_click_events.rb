class CreateClickEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :click_events do |t|
      t.references :visitor, null: false, foreign_key: true
      t.references :site, null: false, foreign_key: true
      t.string :url
      t.bigint :click_time
      t.string :link_id
      t.string :link_href
      t.text :link_contents
      t.integer :link_x
      t.integer :link_y
      t.integer :link_size
      t.integer :click_x
      t.integer :click_y
      t.integer :overtime
      t.jsonb :mouse_speed
      t.jsonb :mouse_acceleration
      t.string :text_analyze

      t.timestamps
    end
  end
end
