class ScopeModelConfigDefaultToKind < ActiveRecord::Migration[8.0]
  def up
    remove_index :model_configs, name: "index_model_configs_on_is_default"
    add_index :model_configs, [:kind, :is_default],
              name: "index_model_configs_on_kind_and_is_default",
              unique: true, where: "is_default = true"
  end

  def down
    remove_index :model_configs, name: "index_model_configs_on_kind_and_is_default"
    add_index :model_configs, :is_default,
              name: "index_model_configs_on_is_default",
              unique: true, where: "is_default = true"
  end
end
