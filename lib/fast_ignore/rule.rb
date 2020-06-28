# frozen_string_literal: true

class FastIgnore
  class Rule
    attr_reader :negation
    alias_method :negation?, :negation
    undef :negation

    attr_reader :dir_only
    alias_method :dir_only?, :dir_only
    undef :dir_only

    attr_reader :anchored
    alias_method :anchored?, :anchored
    undef :anchored

    attr_reader :squashable_type
    attr_reader :rule

    def self.squash(rules)
      first = rules.first
      new(Regexp.union(rules.map(&:rule)).freeze, first.negation?, first.anchored?, first.dir_only?)
    end

    def initialize(rule, negation, anchored, dir_only) # rubocop:disable Metrics/MethodLength
      @rule = rule
      @anchored = anchored
      @dir_only = dir_only
      @negation = negation

      @squashable_type = if anchored && negation
        1
      elsif anchored
        0
      else
        Float::NAN # because it doesn't equal itself
      end

      freeze
    end

    def file_only?
      false
    end

    def shebang
      nil
    end

    # :nocov:
    def inspect
      "#<Rule #{'!' if @negation}#{'/' if @anchored}#{@rule}#{'/' if @dir_only}>"
    end
    # :nocov:

    def match?(relative_path, _, _, _)
      @rule.match?(relative_path)
    end
  end
end
