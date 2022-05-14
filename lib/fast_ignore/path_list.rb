# frozen_string_literal: true

class FastIgnore
  class PathList
    class << self
      include ::FastIgnore::PathListMethods
      include ::Enumerable

      private

      def rule_set
        ::FastIgnore::RuleSet
      end
    end

    include ::FastIgnore::PathListMethods
    include ::Enumerable

    def initialize(rule_set)
      @rule_set = rule_set

      freeze
    end

    def new(rule_set)
      self.class.new(rule_set)
    end

    private

    attr_reader :rule_set
  end
end
