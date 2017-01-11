require "test_helper"

class GarlandsTest < ActiveSupport::TestCase
  setup do
    Event.destroy_all
    Car.destroy_all
    Config.destroy_all
    Program.destroy_all

    @car1 = Car.new(name: "car1"); @car1.save
    @program1 = Program.new(name: "program1", car: @car1); @program1.save
    @program2 = Program.new(name: "program2"); @program2.save

    @hash1 = { a: "a1", b: "b1" }
    @hash2 = { a: "a2", b: "b1" }
    @hash3 = { a: "a3", b: "b1" }
  end

  test "should not save more than one record with next is nil" do
    Event.create!(entity: "{}", entity_type: GarlandRails::DIFF, next: nil, previous: 1)
    item2 = Event.new(entity: "{}", entity_type: GarlandRails::DIFF, next: nil, previous: 1)
    assert_not item2.save
  end

  test "should not save more than one record with previous is nil" do
    Event.create!(entity: "{}", entity_type: GarlandRails::DIFF, next: 1, previous: nil)
    item2 = Event.new(entity: "{}", entity_type: GarlandRails::DIFF, next: 1, previous: nil)
    assert_not item2.save
  end

  test "should not save more than one record with next is nil (belongs)" do
    Config.create!(
      entity: "{}",
      entity_type: GarlandRails::SNAPSHOT,
      belongs_to_id: @program1.id,
      belongs_to_type: "Program",
      next: nil,
    )
    item2 = Config.new(
      entity: "{}",
      entity_type: GarlandRails::SNAPSHOT,
      belongs_to_id: @program1.id,
      belongs_to_type: "Program",
      next: nil,
    )
    assert_not item2.save
  end

  test "should save more than one record with next is nil if it belongs to different objects" do
    Config.create!(
      entity: "{}",
      entity_type: GarlandRails::SNAPSHOT,
      belongs_to_id: @program1.id,
      belongs_to_type: "Program",
      next: 1,
    )
    item2 = Config.new(
      entity: "{}",
      entity_type: GarlandRails::SNAPSHOT,
      belongs_to_id: @program2.id,
      belongs_to_type: "Program",
      next: nil,
    )
    assert item2.save
  end

  test "should not push not hashes" do
    diff = Event.push("not hash")
    assert_not diff
  end

  test "should push hashes" do
    diff1 = Event.push(@hash1)
    assert_equal(HashDiffSym.diff({}, @hash1), eval(diff1.entity))
    assert Event.continuous?(nil)

    diff2 = Event.push(@hash2)
    assert_equal(HashDiffSym.diff(@hash1, @hash2), eval(diff2.entity))
    assert Event.continuous?(nil)

    diff3 = Event.push(@hash3)
    assert_equal(HashDiffSym.diff(@hash2, @hash3), eval(diff3.entity))
    assert Event.continuous?(nil)
  end

  test "should create and restore savepoints on errors" do
  end

  test "should push to table which belong to something" do
    diff1 = Config.push(hash: @hash1, belongs_to: @program1)
    assert_equal(HashDiffSym.diff({}, @hash1), eval(diff1.entity))
  end

  test "should not push empty diffs" do
    Event.push(@hash1)
    Event.push(@hash1)

    # head, first_diff, tail
    assert_equal(3, Event.all.size)
  end

  test "should be able to get head" do
    Event.push(@hash1)
    assert Event.head
  end

  test "should be able to get tail" do
    Event.push(@hash1)
    assert Event.tail
  end

  test "should manage options such as `dependent: :destroy` properly in GarlandRails::Extend.has_many" do
    Config.push(hash: @hash1, belongs_to: @program1)
    assert_equal(3, @program1.configs.size)
    @program1.destroy
    assert_equal(0, Config.where(type: "Program").size)
  end

  test "should manage belongs_to references properly in GarlandRails::Extend.has_many" do
    Config.push(hash: @hash1, belongs_to: @program1)
    Config.push(hash: @hash2, belongs_to: @program1)
    Config.push(hash: @hash3, belongs_to: @car1)

    # head, 2 diffs and tail
    assert_equal(4, @program1.configs.size)

    # head, diff and tail
    assert_equal(3, @car1.configs.size)
  end

  test "shouldn't mess with non-garland references in GarlandRails::Extend.has_many" do
    assert_equal(1, @car1.programs.size)
  end

  test "shouldn't break `join`" do
    Config.push(hash: @hash1, belongs_to: @program1)
    some_config = Config.includes(:program).find_by("programs.name": "program1")
    assert some_config
  end
end
