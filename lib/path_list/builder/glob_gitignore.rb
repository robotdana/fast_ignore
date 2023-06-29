# frozen_string_literal: true

class PathList
  class Builder
    class GlobGitignore < Gitignore
      def initialize(rule, polarity, root) # rubocop:disable Metrics/MethodLength
        rule = +'' if rule.start_with?('#')
        negated_sigil = '!' if rule.delete_prefix!('!')
        if rule.start_with?('*')
          rule = "#{negated_sigil}#{rule}"
        elsif rule.match?(%r{(?:\A[~/]|\A\.{1,2}/|(?:[^\\]|\A)(?:\\{2})*/\.\./)})
          dir_only! if rule.match?(%r{/\s*\z}) # expand_path will remove it
          rule = "#{negated_sigil}#{PathExpander.expand_path(rule, root)}"
          root = '/'
        else
          rule = "#{negated_sigil}/#{rule}"
        end

        super(rule, polarity, root)
      end
    end
  end
end
