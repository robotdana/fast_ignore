# frozen_string_literal: true

class FastIgnore
  class Rule
    attr_reader :dir_only
    alias_method :dir_only?, :dir_only
    undef :dir_only

    attr_reader :squash_id
    attr_reader :rule

    def initialize(rule, negation, dir_only)
      @rule = rule
      @dir_only = dir_only
      @squash_id = negation ? :allow : :ignore

      freeze
    end

    def squash(list)
      self.class.new(::Regexp.union(list.map(&:rule)), @squash_id == :allow, @dir_only)
    end

    def file_only?
      false
    end

    def shebang?
      false
    end

    # :nocov:
    def inspect
      "#<Rule #{@return_value} #{'dir_only ' if @dir_only}#{@rule.inspect}>"
    end
    # :nocov:

    def match?(candidate)
      @squash_id if @rule.match?(candidate.relative_path)
    end
  end
end
