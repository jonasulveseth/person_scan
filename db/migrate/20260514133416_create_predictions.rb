class CreatePredictions < ActiveRecord::Migration[8.0]
  def change
    create_table :predictions do |t|
      t.references :visitor, null: false, foreign_key: true
      t.references :model_config, null: false, foreign_key: true
      t.jsonb :dimensions
      t.string :label
      t.float :confidence
      t.jsonb :raw

      t.timestamps
    end
  end
end
