# frozen_string_literal: true

class FastIgnore
  class RuleList
    include Enumerable

    def initialize(*lines, root: Dir.pwd)
      @lines = lines
      @root = root
    end

    def each(&block)
      return enumerator unless block_given?

      enumerator.each(&block)
    end

    private

    attr_reader :lines, :root

    def enumerator
      Enumerator.new do |yielder|
        lines.reverse_each do |rule|
          rule = FastIgnore::Rule.new(rule, root: root)
          yielder << rule unless rule.skip?
        end
      end
    end
  end
end
