# frozen_string_literal: true

class FastIgnore
  class Rule
    attr_reader :dir_only
    alias_method :dir_only?, :dir_only
    undef :dir_only

    def initialize(rule, negation, anchored, dir_only, label = nil)
      @rule = rule
      @anchored = anchored
      @dir_only = dir_only
      @negation = negation
      @return_value = negation ? :allow : :ignore
      @label = label

      freeze
    end

    def file_only?
      false
    end

    def shebang?
      false
    end

    # :nocov:
    def inspect
      "#<Rule #{@return_value} #{'dir_only ' if @dir_only}#{@rule.inspect} #{@label}>"
    end
    # :nocov:

    def match?(candidate)
      @return_value if @rule.match?(candidate.relative_path)
    end
  end
end
