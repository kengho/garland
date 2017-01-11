class Car < ActiveRecord::Base
  include GarlandRails::Extend
  has_many :configs, dependent: :destroy
  has_many :programs
end
