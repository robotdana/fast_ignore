# frozen_string_literal: true

class FastIgnore
  class PathList
    class << self
      # :nocov:
      # TODO: new api stuff.
      def gitignore(root: nil, append: :gitignore, format: :gitignore) # leftovers:keep
        new.gitignore!(root: root, append: append, format: format)
      end

      def only(*patterns, custom_matcher: nil, from_file: nil, format: nil, root: nil, append: false) # leftovers:keep # rubocop:disable Metrics/ParameterLists
        new.only!(
          *patterns, custom_matcher: custom_matcher, from_file: from_file,
          format: format, root: root, append: append
        )
      end

      def ignore(*patterns, custom_matcher: nil, from_file: nil, format: nil, root: nil, append: false) # leftovers:keep # rubocop:disable Metrics/ParameterLists
        new.ignore!(
          *patterns, custom_matcher: custom_matcher, from_file: from_file,
          format: format, root: root, append: append
        )
      end
      # :nocov:
    end

    include ::Enumerable

    attr_reader :rule_set

    def initialize(rule_set: nil)
      @rule_set = (rule_set || ::FastIgnore::RuleSet)
    end

    def allowed?(path, directory: nil, content: nil, exists: nil, include_directories: false)
      Walkers::FileSystem.allowed?(
        path,
        path_list: self,
        directory: directory,
        content: content,
        exists: exists,
        include_directories: include_directories
      )
    end

    def ===(path)
      Walkers::FileSystem.allowed?(path, path_list: self)
    end

    def to_proc
      method(:allowed?).to_proc
    end

    def each(root: '.', prefix: '', &block)
      return enum_for(:each, root: root, prefix: prefix) unless block
      return unless allowed?(root, include_directories: true)

      Walkers::FileSystem.each(PathExpander.expand_dir(root), prefix, self, &block)
    end

    # :nocov:
    # TODO: new api stuff
    def dup # leftovers:keep
      self.class.new(rule_set: @rule_set)
    end

    def gitignore(root: nil, append: :gitignore, format: :gitignore) # leftovers:keep
      dup.gitignore!(root: root, append: append, format: format)
    end

    def ignore(*patterns, custom_matcher: nil, from_file: nil, format: nil, root: nil, append: false) # leftovers:keep # rubocop:disable Metrics/ParameterLists
      dup.ignore!(
        *patterns, custom_matcher: custom_matcher, from_file: from_file,
        format: format, root: root, append: append
      )
    end

    def only(*patterns, custom_matcher: nil, from_file: nil, format: nil, root: nil, append: false) # leftovers:keep # rubocop:disable Metrics/ParameterLists
      dup.only!(
        *patterns, custom_matcher: custom_matcher, from_file: from_file,
        format: format, root: root, append: append
      )
    end
    # :nocov:

    def gitignore!(root: nil, append: :gitignore, format: :gitignore)
      collect_gitignore = ::FastIgnore::Matchers::CollectGitignore.new(root, format: format, append: append)

      ignore!(custom_matcher: collect_gitignore)
      ignore!(root: root, append: append, format: format)
      ignore!(from_file: ::FastIgnore::GlobalGitignore.path(root: root), root: root, append: append, format: format)
      ignore!(from_file: './.git/info/exclude', root: root, append: append, format: format)
      ignore!(from_file: './.gitignore', root: root, append: append, format: format)
      ignore!('.git', root: '/')

      self
    end

    def ignore!(*patterns, custom_matcher: nil, from_file: nil, format: nil, root: nil, append: false) # rubocop:disable Metrics/ParameterLists
      validate_options(patterns, custom_matcher, from_file)

      @rule_set = @rule_set.new_with_pattern(
        ::FastIgnore::Patterns.new(
          *patterns, custom_matcher: custom_matcher, from_file: from_file,
          format: format, root: root, append: append
        )
      )
      self
    end

    def only!(*patterns, custom_matcher: nil, from_file: nil, format: nil, root: nil, append: false) # rubocop:disable Metrics/ParameterLists
      validate_options(patterns, custom_matcher, from_file)

      @rule_set = @rule_set.new_with_pattern(
        ::FastIgnore::Patterns.new(
          *patterns, custom_matcher: custom_matcher, from_file: from_file,
          format: format, root: root, allow: true, append: append
        )
      )
      self
    end

    private

    def validate_options(patterns, custom_matcher, from_file)
      if [(patterns unless patterns.empty?), custom_matcher, from_file].compact.length > 1
        raise FastIgnore::Error, 'Only use one of *patterns, from_file:, or custom_matcher:'
      end
    end
  end
end
