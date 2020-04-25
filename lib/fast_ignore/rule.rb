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
    undef :negation

    attr_reader :dir_only
    alias_method :dir_only?, :dir_only
    undef :dir_only

    attr_reader :unanchored
    alias_method :unanchored?, :unanchored
    undef :unanchored

    def initialize(rule, unanchored, dir_only, negation)
      @rule = rule
      @unanchored = unanchored
      @dir_only = dir_only
      @negation = negation
      @shebang = shebang

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

    def match?(relative_path, _, _)
      ::File.fnmatch?(@rule, relative_path, 14)
    end
  end
end
