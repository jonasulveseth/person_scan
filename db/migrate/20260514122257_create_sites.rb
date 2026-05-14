class CreateSites < ActiveRecord::Migration[8.0]
  def change
    create_table :sites do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :url
      t.string :public_key, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :sites, :public_key, unique: true
  end
end
