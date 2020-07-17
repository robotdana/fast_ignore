# frozen_string_literal: true

class FastIgnore
  class Rule
    attr_reader :negation
    alias_method :negation?, :negation
    undef :negation

    attr_reader :component_rules
    attr_reader :component_rules_count

    attr_reader :dir_only
    alias_method :dir_only?, :dir_only
    undef :dir_only

    attr_reader :squashable_type
    attr_reader :rule

    def squash(rules)
      # component rules is to improve the performance of repos with many .gitignore files. e.g. linux.
      component_rules = rules.flat_map(&:component_rules)
      ::FastIgnore::Rule.new(
        ::Regexp.union(component_rules.map(&:rule)).freeze,
        @negation, @anchored, @dir_only, component_rules
      )
    end

    def initialize(rule, negation, anchored, dir_only, component_rules = self) # rubocop:disable Metrics/MethodLength
      @rule = rule
      @anchored = anchored
      @dir_only = dir_only
      @negation = negation
      @component_rules = component_rules
      @component_rules_count = component_rules == self ? 1 : component_rules.length

      @squashable_type = if anchored && negation
        1
      elsif anchored
        0
      else
        ::Float::NAN # because it doesn't equal itself
      end

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
      "#<Rule #{'!' if @negation}#{'/' if @anchored}#{@rule}#{'/' if @dir_only}>"
    end
    # :nocov:

    def match?(relative_path, _, _, _)
      @rule.match?(relative_path)
    end
  end
end
