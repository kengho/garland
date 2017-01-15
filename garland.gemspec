Gem::Specification.new do |s|
  s.name        = "garland"
  s.version     = "0.14"
  s.date        = "2017-01-11"
  s.summary     = "HashDiff Rails storage"
  s.description = "Provides GarlandRails::Base class for ActiveRecord, which allows you to save Hashes using snapshots and diffs (in short, it's HashDiff Rails storage)."
  s.authors     = ["Alexander Morozov"]
  s.email       = "ntcomp12@gmail.com"
  s.files       = `git ls-files | grep 'lib/'`.split("\n")
  s.homepage    = "https://github.com/kengho/garland"
  s.license     = "MIT"

  s.add_runtime_dependency "hashdiff_sym", "~> 0"
end
