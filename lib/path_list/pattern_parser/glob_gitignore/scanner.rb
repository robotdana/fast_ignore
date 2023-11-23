# frozen_string_literal: true

class PathList
  class PatternParser
    class GlobGitignore
      # :nocov:
      # this isn't actually nocov, but it's cov is because i reload the file
      SCANNER = if ::File::ALT_SEPARATOR
        Gitignore::WindowsRuleScanner
      else
        Gitignore::RuleScanner
      end
      # :nocov:
    end
  end
end
