module GarlandRails
  DIFF = true
  SNAPSHOT = false

  module Extend
    def self.included(base)
      base.extend(self)
    end

    def has_many(name, scope = nil, options = {}, &extension)
      name_superclass = name.to_s.classify.constantize.superclass
      if name_superclass == GarlandRails::Base
        # if there are no scope and there are some options,
        # scope will contain options, and we need to swap them
        if scope.class == Hash
          options = scope
          scope = nil
        end

        belongs_to_type = self.name
        scope = -> { where(belongs_to_type: belongs_to_type) }
        options = options.merge({ foreign_key: "belongs_to_id" })
      end

      super(name, scope, options, &extension)
    end
  end

  class Base < Garland
    self.table_name = "garlands"

    validates :entity, presence: true
    validates_inclusion_of :entity_type, in: [DIFF, SNAPSHOT]

    # for given parent object, described by "belongs_to_id" and "belongs_to_type",
    # there are only one record of each type which is head or tail
    validates_uniqueness_of :type, scope: [
      :belongs_to_id,
      :belongs_to_type,
      :next,
    ], conditions: -> { where("next IS NULL OR previous IS NULL") }

    # everything seems to work without `polymorphic: true`,
    # but we will set it just for accordance to docs
    def self.belongs_to(name, scope = nil, options = {}, &extension)
      if scope.class == Hash
        options = scope
        scope = nil
      end
      options = options.merge({ foreign_key: "belongs_to_id" })

      super(name, scope, options, &extension)
    end

    def self.push(args)
      return nil unless args.class == Hash

      if args[:hash]
        hash = args[:hash]
        return nil unless hash.class == Hash

        belongs_to = args[:belongs_to]
        if belongs_to
          belongs_to_params = self._split_belongs_to(belongs_to)
          belongs_to_id = belongs_to_params[:belongs_to_id]
          belongs_to_type = belongs_to_params[:belongs_to_type]
        end
      else
        hash = args
        belongs_to = nil
        belongs_to_id = nil
        belongs_to_type = nil
      end

      head = self.head(belongs_to)
      if head
        diff = self.insert_diff(hash, belongs_to)
      else
        diff = self.init(hash, belongs_to)
      end

      diff
    end

    def self.thread(belongs_to = nil)
      if belongs_to
        return self.where(
          "belongs_to_id = ? AND belongs_to_type = ?",
          belongs_to.id, table_type(belongs_to)
        )
      else
        return self.where("belongs_to_id is null AND belongs_to_type is null")
      end
    end

    def self.tail(belongs_to = nil)
      self.thread(belongs_to).find_by(previous: nil)
    end

    def self.head(belongs_to = nil)
      self.thread(belongs_to).find_by(next: nil)
    end

    def self.last_diff(belongs_to = nil)
      head = self.head(belongs_to)

      self.find_by(id: head.previous)
    end

    def self.table_type(record)
      record.class.name
    end

    def self.any?(belongs_to = nil)
      self.thread(belongs_to).any?
    end

    def self.init(hash, belongs_to = nil)
      common_props = self._split_belongs_to(belongs_to)

      tail_props = common_props.merge({ entity: {}.to_s, entity_type: SNAPSHOT })
      brand_new_tail = self.new(tail_props)

      diff = HashDiffSym.diff({}, hash)
      first_diff_props = common_props.merge({ entity: diff.to_s, entity_type: DIFF })
      first_diff = self.new(first_diff_props)

      head_props = common_props.merge({ entity: hash.to_s, entity_type: SNAPSHOT })
      brand_new_head = self.new(head_props)

      self.transaction do
         ActiveRecord::Base.connection.create_savepoint("savepoint_before_init")

         # first id: tail ({})
         # second id: head (latest snapshot)
         # third+: diffs
         unless brand_new_tail.save
           Rails.logger.error("Unable to create new tail with props '#{tail_props}'")
           ActiveRecord::Base.connection.release_savepoint("savepoint_before_init")
           return nil
         end

         # belongs_to validations were in `brand_new_tail.save`
         # here and below validations may be skipped as long as we check for continuity later
         brand_new_head.save(validate: false)
         first_diff.save(validate: false)
         brand_new_tail.update_attribute(:next, first_diff.id)
         first_diff.update_attribute(:previous, brand_new_tail.id)
         first_diff.update_attribute(:next, brand_new_head.id)
         brand_new_head.update_attribute(:previous, first_diff.id)

         unless self.continuous?(belongs_to)
           Rails.logger.error("Initialized garland is not continuous")
           ActiveRecord::Base.connection.exec_rollback_to_savepoint("savepoint_before_init")
           ActiveRecord::Base.connection.release_savepoint("savepoint_before_init")
           return nil
         end
      end

      first_diff
    end

    def self.insert_diff(hash, belongs_to = nil)
      head = self.head(belongs_to)
      last_diff = self.find_by(id: head.previous)
      common_props = self._split_belongs_to(belongs_to)

      diff = HashDiffSym.diff(eval(head.entity), hash)
      return unless diff.any?

      new_diff_props = common_props.merge({
        entity: diff.to_s,
        entity_type: DIFF,
        previous: last_diff.id,
        next: head.id,
      })
      new_diff = self.new(new_diff_props)

      self.transaction do
         ActiveRecord::Base.connection.create_savepoint("savepoint_before_insert_diff")

         # insert_diff should not use skipping valudatuons methods
         # because we don't want to check for continuity on every push
         unless new_diff.save
           Rails.logger.error("Unable to create new_diff with props '#{new_diff_props}'")
           ActiveRecord::Base.connection.release_savepoint("savepoint_before_init")
           return nil
         end

         last_diff.next = new_diff.id
         unless last_diff.save
           Rails.logger.error("Unable to save last_diff with 'next' = '#{new_diff.id}'")
           ActiveRecord::Base.connection.exec_rollback_to_savepoint("savepoint_before_insert_diff")
           ActiveRecord::Base.connection.release_savepoint("savepoint_before_init")
           return nil
         end

         head.previous = new_diff.id
         unless head.save
           Rails.logger.error("Unable to save head with 'previous' = '#{new_diff.id}'")
           ActiveRecord::Base.connection.exec_rollback_to_savepoint("savepoint_before_insert_diff")
           ActiveRecord::Base.connection.release_savepoint("savepoint_before_init")
           return nil
         end

         head.entity = hash.to_s
         unless head.save
           Rails.logger.error("Unable to save head with 'entity' = '#{hash.to_s}'")
           ActiveRecord::Base.connection.exec_rollback_to_savepoint("savepoint_before_insert_diff")
           ActiveRecord::Base.connection.release_savepoint("savepoint_before_init")
           return nil
         end
      end

      new_diff
    end

    def self.continuous?(belongs_to = nil)
      tail = self.tail(belongs_to)
      head = self.head(belongs_to)
      return false unless tail && head

      current_bulb = tail
      current_hash = eval(tail.entity)
      items_counted = 1
      while current_bulb.next do
        items_counted += 1
        current_bulb = self.find_by(id: current_bulb.next)
        if current_bulb.entity_type == DIFF
          current_hash = HashDiffSym.patch!(current_hash, eval(current_bulb.entity))
        else
          break
        end
      end

      items_counted == self.thread(belongs_to).size && current_hash == eval(head.entity)
    end

    private
      def self._split_belongs_to(belongs_to)
        if belongs_to
          belongs_to_id = belongs_to.id
          belongs_to_type = table_type(belongs_to)
        else
          belongs_to_id = nil
          belongs_to_type = nil
        end

        { belongs_to_id: belongs_to_id, belongs_to_type: belongs_to_type }
      end
  end
end
