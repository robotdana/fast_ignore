# frozen_string_literal: true

class FastIgnore
  class Rule
    # FNMATCH_OPTIONS = (
    #   ::File::FNM_DOTMATCH |
    #   ::File::FNM_PATHNAME |
    #   ::File::FNM_CASEFOLD
    # ).freeze # = 14

    attr_reader :negation
    alias_method :negation?, :negation
    attr_reader :dir_only
    alias_method :dir_only?, :dir_only

    attr_reader :rule

    def initialize(rule, dir_only, negation)
      @rule = rule
      @dir_only = dir_only
      @negation = negation

      freeze
    end

    # :nocov:
    def inspect
      "#<Rule #{'!' if negation?}#{rule}#{'/' if dir_only?}>"
    end
    # :nocov:
  end
end
