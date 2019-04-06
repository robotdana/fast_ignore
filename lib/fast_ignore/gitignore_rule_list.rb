# frozen_string_literal: true

class FastIgnore
  class GitignoreRuleList
    include Enumerable

    def each(&block)
      FastIgnore::RuleList.new('.git').each(&block)
      FastIgnore::FileRuleList.new(File.join(Dir.pwd, '.gitignore')).each(&block)
    end
  end
end
