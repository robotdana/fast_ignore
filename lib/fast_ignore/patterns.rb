# frozen-string-literal: true

class FastIgnore
  class Patterns
    attr_reader :from_file
    attr_reader :root
    attr_reader :patterns
    attr_reader :label
    attr_reader :allow
    attr_reader :format
    attr_reader :custom_matcher

    BUILDERS = {
      expand_path_gitignore: FastIgnore::Builders::ExpandPathGitignore,
      gitignore: Builders::Gitignore,
      shebang_or_expand_path_gitignore: FastIgnore::Builders::ShebangOrExpandPathGitignore,
      shebang_or_gitignore: FastIgnore::Builders::ShebangOrGitignore,
      shebang: FastIgnore::Builders::Shebang
    }.freeze

    def initialize(*patterns, custom_matcher: nil, from_file: nil, format: nil, root: nil, allow: false, append: false) # rubocop:disable Metrics/MethodLength, Metrics/ParameterLists, Metrics/AbcSize
      @allow = allow
      @label = append
      if custom_matcher
        @custom_matcher = custom_matcher
      else
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
    end

    def ==(other) # rubocop:disable Metrics/AbcSize
      @label == other.label &&
        @custom_matcher == other.custom_matcher &&
        allow == other.allow &&
        from_file == other.from_file &&
        root == other.root &&
        patterns == other.patterns &&
        format == other.format
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
      return [@custom_matcher] if custom_matcher

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
