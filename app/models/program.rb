class Program < ActiveRecord::Base
  include GarlandRails::Extend
  has_many :configs
  belongs_to :car
end
