class CreateEvents < ActiveRecord::Migration
  def change
    create_table :events do |t|
      t.string :event_id
      t.text :payload
      t.timestamp :successful_at
      t.string :timestamps

      t.timestamps

    end

    add_index :events, :event_id, unique: true
  end
end
