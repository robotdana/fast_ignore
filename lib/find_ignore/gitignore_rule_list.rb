# frozen_string_literal: true

class FindIgnore
  class GitignoreRuleList
    include Enumerable

    def each(&block)
      FindIgnore::RuleList.new('.git').each(&block)
      FindIgnore::FileRuleList.new(File.join(Dir.pwd, '.gitignore')).each(&block)
    end
  end
end
