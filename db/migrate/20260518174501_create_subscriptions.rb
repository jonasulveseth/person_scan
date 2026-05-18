class CreateSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :stripe_subscription_id, null: false
      t.string :stripe_price_id
      t.string :plan, null: false
      t.string :status, null: false
      t.datetime :trial_ends_at
      t.datetime :current_period_end

      t.timestamps
    end
    add_index :subscriptions, :stripe_subscription_id, unique: true
  end
end
