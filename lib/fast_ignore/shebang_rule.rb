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

    def initialize(rule, negation)
      @rule = rule
      @negation = negation
      @return_value = negation ? :allow : :ignore

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
      "#<ShebangRule #{@return_value} /#{@rule.to_s[26..-4]}/>"
    end
    # :nocov:

    def match?(candidate)
      return false if candidate.filename.include?('.')

      @return_value if candidate.first_line&.match?(@rule)
    end

    def shebang?
      true
    end
  end
end
