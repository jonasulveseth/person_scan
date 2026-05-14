class CreatePageVisits < ActiveRecord::Migration[8.0]
  def change
    create_table :page_visits do |t|
      t.references :visitor, null: false, foreign_key: true
      t.references :site, null: false, foreign_key: true
      t.string :url
      t.bigint :visit_time
      t.boolean :leave
      t.jsonb :click_data

      t.timestamps
    end
  end
end
