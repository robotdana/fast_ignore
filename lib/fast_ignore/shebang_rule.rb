# frozen_string_literal: true

class FastIgnore
  class ShebangRule
    attr_reader :negation
    alias_method :negation?, :negation
    undef :negation

    attr_reader :rule

    attr_reader :file_path_pattern

    # attr_reader :squashable_type

    # def squash(rules)
    #   ::FastIgnore::ShebangRule.new(::Regexp.union(rules.map(&:rule)).freeze, negation?, file_path_pattern)
    # end

    # def component_rules_count
    #   1
    # end

    def initialize(rule, negation, file_path_pattern)
      @rule = rule
      @negation = negation
      @file_path_pattern = file_path_pattern

      # @squashable_type = (negation ? 13 : 12) + file_path_pattern.object_id

      freeze
    end

    def file_only?
      true
    end

    def dir_only?
      false
    end

    # :nocov:
    def inspect
      allow_fragment = 'allow ' if @negation
      in_fragment = " in #{@file_path_pattern}" if @file_path_pattern
      "#<ShebangRule #{allow_fragment}#!:#{@rule.to_s[15..-4]}#{in_fragment}>"
    end
    # :nocov:

    def match?(candidate)
      return false if candidate.filename.include?('.')
      return false unless (not @file_path_pattern) || @file_path_pattern.match?(candidate.relative_path_to_root)

      candidate.first_line&.match?(@rule)
    end

    def shebang?
      true
    end
  end
end
