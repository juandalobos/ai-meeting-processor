class CreateBusinessContexts < ActiveRecord::Migration[8.0]
  def change
    create_table :business_contexts do |t|
      t.string :name
      t.text :content
      t.string :context_type

      t.timestamps
    end
  end
end
