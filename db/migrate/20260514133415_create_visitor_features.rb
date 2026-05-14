class CreateVisitorFeatures < ActiveRecord::Migration[8.0]
  def change
    create_table :visitor_features do |t|
      t.references :visitor, null: false, foreign_key: true, index: { unique: true }
      t.jsonb :features, null: false, default: {}
      t.datetime :computed_at, null: false

      t.timestamps
    end
  end
end
