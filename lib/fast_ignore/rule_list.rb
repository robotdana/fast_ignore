# frozen_string_literal: true

class FastIgnore
  class RuleList
    include Enumerable

    def initialize(*lines)
      @lines = lines
    end

    def each(&block)
      return enumerator unless block_given?

      enumerator.each(&block)
    end

    private

    attr_reader :lines

    def enumerator
      Enumerator.new do |yielder|
        lines.reverse_each do |rule|
          rule = FastIgnore::Rule.new(rule)
          yielder << rule unless rule.skip?
        end
      end
    end
  end
end
