Gem::Specification.new do |s|
  s.name        = "garland"
  s.version     = "0.12"
  s.date        = "2017-01-08"
  s.summary     = "HashDiff ActiveRecord storage"
  s.description = "Provides GarlandRails::Base class for ActiveRecord, which allows you to save Hashes using snapshots and diffs (in short, it's HashDiff Rails storage)."
  s.authors     = ["Alexander Morozov"]
  s.email       = "ntcomp12@gmail.com"
  s.files       = ["lib/garland.rb", "lib/garland_rails.rb"]
  s.homepage    = "https://github.com/kengho/garland"
  s.license     = "MIT"

  s.add_runtime_dependency "hashdiff_sym", "~> 0"
end
