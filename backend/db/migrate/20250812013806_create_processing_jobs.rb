class CreateProcessingJobs < ActiveRecord::Migration[8.0]
  def change
    create_table :processing_jobs do |t|
      t.references :meeting, null: false, foreign_key: true
      t.string :job_type
      t.string :status
      t.text :result

      t.timestamps
    end
  end
end
