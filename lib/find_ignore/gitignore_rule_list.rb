# frozen_string_literal: true

require_relative './rule_list'

class FindIgnore
  class GitignoreRuleList < RuleList
    def initialize(file: nil)
      file ||= File.join(Dir.pwd, '.gitignore')
      super('.git', file: file)
    end
  end
end
