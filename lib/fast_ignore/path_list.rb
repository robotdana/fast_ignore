# frozen_string_literal: true

class FastIgnore
  class PathList
    class << self
      # :nocov:
      # TODO: new api stuff.
      def gitignore(root: nil, append: :gitignore, format: :gitignore) # leftovers:keep
        new.gitignore!(root: root, append: append, format: format)
      end

      def only(*patterns, from_file: nil, format: nil, root: nil, append: false) # leftovers:keep
        new.only!(*patterns, from_file: from_file, format: format, root: root, append: append)
      end

      def ignore(*patterns, from_file: nil, format: nil, root: nil, append: false) # leftovers:keep
        new.ignore!(*patterns, from_file: from_file, format: format, root: root, append: append)
      end
      # :nocov:
    end

    include ::Enumerable

    attr_reader :matcher

    def initialize(matcher: Matchers::All.new([]))
      @matcher = matcher
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
      # :nocov:
      # TODO: new api stuff
      return unless Walkers::FileSystem.allowed?(
        root, path_list: self, include_directories: true, parent_if_directory: true
      )

      # :nocov:

      Walkers::FileSystem.each(PathExpander.expand_dir(root), prefix, self, &block)
    end

    # :nocov:
    # TODO: new api stuff
    def dup # leftovers:keep
      self.class.new(matcher: @matcher)
    end

    def gitignore(root: nil, append: :gitignore, format: :gitignore) # leftovers:keep
      dup.gitignore!(root: root, append: append, format: format)
    end

    def ignore(*patterns, from_file: nil, format: nil, root: nil, append: false) # leftovers:keep
      dup.ignore!(*patterns, from_file: from_file, format: format, root: root, append: append)
    end

    def only(*patterns, from_file: nil, format: nil, root: nil, append: false) # leftovers:keep
      dup.only!(*patterns, from_file: from_file, format: format, root: root, append: append)
    end
    # :nocov:

    def gitignore!(root: nil, append: :gitignore, format: :gitignore)
      collect_gitignore = Matchers::CollectGitignore.new(root, format: format, append: append)

      @matcher = Matchers::All.new([@matcher, collect_gitignore])
      ignore!(root: root, append: append, format: format)
      ignore!(from_file: GlobalGitignore.path(root: root), root: root || '.', append: append, format: format)
      ignore!(from_file: './.git/info/exclude', root: root || '.', append: append, format: format)
      ignore!(from_file: './.gitignore', root: root, append: append, format: format)
      ignore!('.git', root: '/')

      self
    end

    def ignore!(*patterns, from_file: nil, format: nil, root: nil, append: nil)
      validate_options(patterns, from_file)

      and_pattern(
        Patterns.new(*patterns, from_file: from_file, format: format, root: root, append: append)
      )
      self
    end

    def only!(*patterns, from_file: nil, format: nil, root: nil, append: nil)
      validate_options(patterns, from_file)

      and_pattern(
        Patterns.new(*patterns, from_file: from_file, format: format, root: root, allow: true, append: append)
      )

      self
    end

    private

    def and_pattern(pattern)
      @matcher = if pattern.label
        @matcher.append(pattern) || Matchers::All.new([@matcher, pattern.build])
      else
        Matchers::All.new([@matcher, pattern.build])
      end
    end

    def validate_options(patterns, from_file)
      # :nocov:
      # TODO: new api stuff
      if [(patterns unless patterns.empty?), from_file].compact.length > 1
        raise FastIgnore::Error, 'Only use one of *patterns or from_file:'
      end
      # :nocov:
    end
  end
end
