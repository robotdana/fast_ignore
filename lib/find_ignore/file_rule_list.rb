# frozen_string_literal: true

require_relative './rule'

class FindIgnore
  class FileRuleList < FindIgnore::RuleList
    def initialize(file)
      @lines = IO.foreach(file)
    end
  end
end
