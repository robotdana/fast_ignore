# frozen_string_literal: true

class FastIgnore
  class ShebangRule
    def initialize(rule, negation)
      @rule = rule
      @negation = negation
      @return_value = negation ? :allow : :ignore

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
