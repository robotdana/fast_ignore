# frozen_string_literal: true

class FastIgnore
  class Rule
    attr_reader :negation
    alias_method :negation?, :negation
    undef :negation

    attr_reader :dir_only
    alias_method :dir_only?, :dir_only
    undef :dir_only

    attr_reader :unanchored
    alias_method :unanchored?, :unanchored
    undef :unanchored

    attr_reader :type
    attr_reader :rule

    def initialize(rule, negation, unanchored = nil, dir_only = nil)
      @rule = rule.is_a?(Regexp) ? rule : ::FastIgnore::FNMatchToRegex.call(rule)
      @unanchored = unanchored
      @dir_only = dir_only
      @negation = negation

      @type = negation ? 1 : 0

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
      "#<Rule #{'!' if @negation}#{@rule}#{'/' if @dir_only}>"
    end
    # :nocov:

    def match?(relative_path, _, _, _)
      @rule.match?(relative_path)
    end
  end
end
