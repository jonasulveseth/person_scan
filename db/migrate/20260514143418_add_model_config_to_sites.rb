class AddModelConfigToSites < ActiveRecord::Migration[8.0]
  def change
    add_reference :sites, :model_config, null: true, foreign_key: true
  end
end
