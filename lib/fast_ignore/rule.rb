# frozen_string_literal: true

class FastIgnore
  class Rule

    FNMATCH_OPTIONS = (::File::FNM_DOTMATCH | ::File::FNM_PATHNAME | ::File::FNM_CASEFOLD).freeze

    def initialize(rule, dir_only, negation)
      @rule = rule
      @dir_only = dir_only
      @negation = negation
    end

    def negation?
      @negation
    end

    def dir_only?
      @dir_only
    end

    def match?(path)
      ::File.fnmatch?(@rule, path, ::FastIgnore::Rule::FNMATCH_OPTIONS)
    end
  end
end
