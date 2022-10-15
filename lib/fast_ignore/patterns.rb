# frozen_string_literal: true

class FastIgnore
  class Patterns
    attr_reader :from_file
    attr_reader :root
    attr_reader :label
    attr_reader :allow
    attr_reader :format

    BUILDERS = {
      expand_path_gitignore: FastIgnore::Builders::ExpandPathGitignore,
      gitignore: Builders::Gitignore,
      shebang_or_expand_path_gitignore: FastIgnore::Builders::ShebangOrExpandPathGitignore,
      shebang_or_gitignore: FastIgnore::Builders::ShebangOrGitignore,
      shebang: FastIgnore::Builders::Shebang
    }.freeze

    def initialize(*patterns, from_file: nil, format: nil, root: nil, allow: false, append: nil) # rubocop:disable Metrics/MethodLength, Metrics/ParameterLists
      @allow = allow
      @label = "#{allow}_#{append}" if append
      root = PathExpander.expand_dir(root) if root

      if from_file
        @from_file = PathExpander.expand_path(from_file, root || '.')
        root ||= ::File.dirname(from_file)
      else
        @patterns = patterns.flatten.flat_map { |string| string.to_s.lines }.freeze
      end

      @root = PathExpander.expand_dir(root || '.')
      @format = BUILDERS.fetch(format || :gitignore, format)
    end

    def build
      matcher = ::FastIgnore::Matchers::LastMatch.new(build_matchers)
      matcher = Matchers::Appendable.new(@label, matcher) if @label

      ::FastIgnore::Matchers::MatchOrDefault.new(matcher, default)
    end

    def build_appended
      build_matchers
    end

    def default
      @allow ? :ignore : :allow
    end

    private

    def read_patterns
      if from_file
        ::File.exist?(@from_file) ? ::File.readlines(@from_file) : []
      else
        @patterns
      end
    end

    def build_matchers
      matchers = read_patterns.flat_map { |p| format.build(p, @allow, @root) }.compact
      return matchers if matchers.empty?

      matcher = Matchers::MatchByType.build_from_list(matchers)
      matcher = Matchers::WithinDir.new(matcher, @root)
      return [matcher] unless @allow

      [matcher, Matchers::Any.new(GitignoreIncludeRuleBuilder.new(@root).build_as_parent)]
    end
  end
end
