class CreateTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :tasks do |t|
      t.string :title
      t.text :description
      t.integer :status, default: 0, null: false

      t.timestamps
    end
  end
end
