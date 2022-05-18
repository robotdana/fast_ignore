# frozen-string-literal: true

class FastIgnore
  class Patterns
    attr_reader :from_file
    attr_reader :root
    attr_reader :patterns
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

    def initialize(*patterns, from_file: nil, format: nil, root: nil, allow: false, append: false) # rubocop:disable Metrics/MethodLength, Metrics/ParameterLists, Metrics/AbcSize
      @allow = allow
      @label = append
      root = PathExpander.expand_dir(root) if root

      if from_file
        @from_file = PathExpander.expand_path(from_file, root || '.')
        root ||= ::File.dirname(from_file)
      else
        @patterns = patterns.flatten.flat_map { |string| string.to_s.lines }.freeze
      end
      @root = PathExpander.expand_dir(root || '.')
      @format ||= BUILDERS.fetch(format || :gitignore, format)
    end

    def ==(other)
      @label == other.label &&
        allow == other.allow &&
        from_file == other.from_file &&
        @root == other.root &&
        patterns == other.patterns &&
        @format == other.format
    end
    alias_method :eql?, :==

    def label_or_self
      @label || object_id
    end

    def matchers
      @matchers ||= build_matchers
    end

    def build
      @build ||= begin
        ::FastIgnore::Matchers::MatchOrDefault.new(
          ::FastIgnore::Matchers::LastMatch.new(matchers),
          default
        )
      end
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
      return [::FastIgnore::Matchers::WithinDir.new(matchers, @root)] unless @allow

      [
        ::FastIgnore::Matchers::WithinDir.new(matchers, @root),
        ::FastIgnore::Matchers::WithinDir.new(
          ::FastIgnore::GitignoreIncludeRuleBuilder.new(@root).build_as_parent, '/'
        )
      ]
    end
  end
end
