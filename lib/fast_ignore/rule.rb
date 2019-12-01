# frozen_string_literal: true

class FastIgnore
  class Rule
    unless ::RUBY_VERSION >= '2.4'
      require_relative 'backports/match'
      using ::FastIgnore::Backports::Match
    end

    FNMATCH_OPTIONS = (::File::FNM_DOTMATCH | ::File::FNM_PATHNAME | ::File::FNM_CASEFOLD).freeze

    def initialize(rule, dir_only, negation, anchored)
      @rule = rule
      @dir_only = dir_only
      @negation = negation
      @anchored = anchored
    end

    attr_reader :rule

    def anchored?
      @anchored
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
