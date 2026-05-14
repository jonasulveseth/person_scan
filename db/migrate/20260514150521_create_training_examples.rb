class CreateTrainingExamples < ActiveRecord::Migration[8.0]
  def change
    create_table :training_examples do |t|
      t.jsonb :features, null: false, default: {}
      t.jsonb :ground_truth, null: false, default: {}
      t.string :source, null: false
      t.text :notes
      t.references :visitor, null: true, foreign_key: true
      t.string :legacy_cookie_id

      t.timestamps
    end
    add_index :training_examples, :source
    add_index :training_examples, :legacy_cookie_id
  end
end
