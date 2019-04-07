# frozen_string_literal: true

class FastIgnore
  class GitignoreRuleList
    include Enumerable

    def initialize(file)
      @file = file
    end

    def each(&block)
      FastIgnore::RuleList.new('.git').each(&block)
      FastIgnore::FileRuleList.new(file).each(&block)
    end

    private

    attr_reader :file
  end
end
