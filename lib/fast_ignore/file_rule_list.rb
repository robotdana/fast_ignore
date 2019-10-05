# frozen_string_literal: true

require_relative './rule'

class FastIgnore
  class FileRuleList < ::FastIgnore::RuleList
    def initialize(file, root: ::File.dirname(file))
      @lines = ::IO.foreach(file)
      @root = root
    end
  end
end
