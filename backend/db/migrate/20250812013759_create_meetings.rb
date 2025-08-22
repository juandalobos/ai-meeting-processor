class CreateMeetings < ActiveRecord::Migration[8.0]
  def change
    create_table :meetings do |t|
      t.string :title, null: true
      t.text :description, null: true
      t.string :status

      t.timestamps
    end
  end
end
