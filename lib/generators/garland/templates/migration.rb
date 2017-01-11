class CreateGarlands < ActiveRecord::Migration[5.0]
  def change
    create_table :garlands do |t|
      t.text :entity, null: false
      t.boolean :entity_type, null: false
      t.integer :previous
      t.integer :next
      t.integer :belongs_to_id
      t.string :belongs_to_type
      t.string :type
      t.timestamps
    end
  end
end
