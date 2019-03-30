# frozen_string_literal: true

require_relative './rule'

class FindIgnore
  class RuleList
    include Enumerable

    def initialize(*rules, file: nil)
      @rules = rules
      @file = file
    end

    def each(&block)
      enumerator.each(&block)
    end

    private

    def enumerator
      Enumerator.new do |yielder|
        prepare_rules = lambda do |rule|
          rule = FindIgnore::Rule.new(rule)
          yielder << rule unless rule.skip?
        end

        @rules&.each(&prepare_rules)
        IO.foreach(file).each(&prepare_rules) if file
      end
    end

    attr_reader :file, :rules
  end
end
