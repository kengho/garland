class AddCarIdToProgram < ActiveRecord::Migration[5.0]
  def change
    add_column :programs, :car_id, :integer
  end
end
