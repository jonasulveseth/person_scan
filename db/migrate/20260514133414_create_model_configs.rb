class CreateModelConfigs < ActiveRecord::Migration[8.0]
  def change
    create_table :model_configs do |t|
      t.string :name, null: false
      t.string :provider, null: false
      t.string :model_id, null: false
      t.text :prompt_template, null: false
      t.boolean :active, null: false, default: true
      t.boolean :is_default, null: false, default: false

      t.timestamps
    end
    add_index :model_configs, :name, unique: true
    add_index :model_configs, :is_default, unique: true, where: "is_default = true"
  end
end
