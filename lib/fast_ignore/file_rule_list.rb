# frozen_string_literal: true

require_relative './rule'

class FastIgnore
  class FileRuleList < FastIgnore::RuleList
    def initialize(file)
      @lines = IO.foreach(file)
    end
  end
end
