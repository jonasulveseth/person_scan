class CreateEvaluationRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :evaluation_runs do |t|
      t.references :model_config, null: false, foreign_key: true
      t.datetime :started_at
      t.datetime :finished_at
      t.integer :total
      t.integer :correct_gender
      t.integer :correct_age_bracket
      t.float :avg_confidence
      t.jsonb :results

      t.timestamps
    end
  end
end
