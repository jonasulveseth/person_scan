class AddKindToModelConfigs < ActiveRecord::Migration[8.0]
  def up
    add_column :model_configs, :kind, :string, default: "persona", null: false
    add_index  :model_configs, :kind
    ModelConfig.reset_column_information
    ModelConfig.where(kind: nil).update_all(kind: "persona")
  end

  def down
    remove_index  :model_configs, :kind
    remove_column :model_configs, :kind
  end
end
