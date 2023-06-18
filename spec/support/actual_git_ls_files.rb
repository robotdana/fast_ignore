# frozen_string_literal: true

class ActualGitLSFiles
  def to_a
    # unfortunately git likes to output path names with quotes and escaped backslashes.
    # we need the string without quotes and without escaped backslashes.
    system('git init', out: File::NULL)
    system("git -c core.excludesfile='' add -N .", out: File::NULL)
    `git -c core.excludesfile='' ls-files`
      .split("\n")
      .map do |path|
        next path unless path[0] == '"' && path[-1] == '"'

        path[1..-2].gsub('\\\\', '\\')
      end
  end
end
