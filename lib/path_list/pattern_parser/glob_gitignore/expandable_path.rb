# frozen_string_literal: true

class PathList
  class PatternParser
    class GlobGitignore
      EXPANDABLE_PATH = if File.expand_path('/') == '/'
        %r{(?:\A(?:[~/]|\.{1,2}(?:/|\z))|(?:[^\\]|\A)(?:\\{2})*/\.\./)}
        # :nocov:
      else
        # this isn't actually nocov, but it's cov is because i reload the file
        %r{(?:\A(?:[~/\\]|[a-zA-Z]:[/\\]|[/\\]{2}|\.{1,2}(?:[/\\]|\z))|[\\/]\.\.[/\\])}
        # :nocov:
      end
    end
  end
end
