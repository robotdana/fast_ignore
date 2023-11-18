# frozen_string_literal: true

class PathList
  class PatternParser
    class GlobGitignore
      # :nocov:
      # this isn't actually nocov, but it's cov is because i reload the file
      EXPANDABLE_PATH = %r{(?:
        \A(?:
          [~/] # start with slash or tilde
          |
          \.{1,2}(?:/|\z) # start with dot or dot dot followed by slash or nothing
          #{
            if ::File.expand_path('/') != '/' # only if drive letters are applicable
              "
              |
              [a-zA-Z]:/ # drive letter
              |
              // # UNC path
              "
            end
          }
        )
        |
        (?:[^\\]|\A)(?:\\{2})*/\.\./) # unescaped slash dot dot slash
      }x.freeze
      # :nocov:
    end
  end
end
