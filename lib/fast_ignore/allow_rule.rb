# frozen_string_literal: true

class FastIgnore
  class AllowRule
    attr_reader :dir_only
    alias_method :dir_only?, :dir_only
    undef :dir_only

    attr_reader :squash_id
    attr_reader :rule

    def initialize(rule, anchored, dir_only)
      @rule = rule
      @dir_only = dir_only
      @anchored = anchored
      @squash_id = anchored ? :allow : object_id

      freeze
    end

    def squash(list)
      self.class.new(::Regexp.union(list.map(&:rule)), @anchored, @dir_only)
    end

    def file_only?
      false
    end

    def shebang?
      false
    end

    # :nocov:
    def inspect
      "#<AllowRule #{'dir_only ' if @dir_only}#{@rule.inspect}>"
    end
    # :nocov:

    def match?(candidate)
      :allow if @rule.match?(candidate.relative_path)
    end
  end
end
