class CreateApiKeys < ActiveRecord::Migration[8.0]
  def change
    create_table :api_keys do |t|
      t.references :site, null: false, foreign_key: true
      t.string :name, null: false
      t.string :token, null: false
      t.datetime :last_used_at
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :api_keys, :token, unique: true
  end
end
