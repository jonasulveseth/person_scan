class AddTimeToFirstMoveMsToTrackingEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :tracking_events, :time_to_first_move_ms, :integer
  end
end
