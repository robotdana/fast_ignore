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

      def walker(walker) # leftovers:keep
        new.walker!(walker)
      end
      # :nocov:
    end

    include ::Enumerable

    attr_reader :rule_set

    def initialize(rule_set: nil, walker: nil)
      @rule_set = (rule_set || ::FastIgnore::RuleSet)
      @walker = walker
    end

    def allowed?(path, directory: nil, content: nil, exists: nil, include_directories: false)
      walk.allowed?(
        path,
        path_list: self,
        directory: directory,
        content: content,
        exists: exists,
        include_directories: include_directories
      )
    end

    def ===(path)
      walk.allowed?(path, path_list: self)
    end

    def to_proc
      method(:allowed?).to_proc
    end

    def each(root: '.', prefix: '', &block)
      return enum_for(:each, root: root, prefix: prefix) unless block

      walk.each(PathExpander.expand_dir(root), prefix, self, &block)
    end

    # :nocov:
    # TODO: new api stuff
    def dup # leftovers:keep
      self.class.new(rule_set: @rule_set, walker: @walker)
    end

    def gitignore(root: nil, append: :gitignore, format: :gitignore) # leftovers:keep
      dup.gitignore!(root: root, append: append, format: format)
    end

    def walker(walker) # leftovers:keep
      dup.walker!(walker)
    end

    def ignore(*patterns, from_file: nil, format: nil, root: nil, append: false) # leftovers:keep
      dup.ignore!(*patterns, from_file: from_file, format: format, root: root, append: append)
    end

    def only(*patterns, from_file: nil, format: nil, root: nil, append: false) # leftovers:keep
      dup.only!(*patterns, from_file: from_file, format: format, root: root, append: append)
    end
    # :nocov:

    def gitignore!(root: nil, append: :gitignore, format: :gitignore)
      ignore!(root: root, append: append, format: format)
      ignore!(from_file: ::FastIgnore::GlobalGitignore.path(root: root), root: root, append: append, format: format)
      ignore!(from_file: './.git/info/exclude', root: root, append: append, format: format)
      ignore!(from_file: './.gitignore', root: root, append: append, format: format)
      ignore!('.git', root: '/')
      walker!(::FastIgnore::Walkers::GitignoreCollectingFileSystem.new(root, format: format, append: append))

      self
    end

    def walker!(walker)
      @walker = walker

      self
    end

    def ignore!(*patterns, from_file: nil, format: nil, root: nil, append: false)
      @rule_set = @rule_set.new(
        ::FastIgnore::Patterns.new(
          *patterns, from_file: from_file, format: format, root: root, append: append
        )
      )
      self
    end

    def only!(*patterns, from_file: nil, format: nil, root: nil, append: false)
      @rule_set = @rule_set.new(
        ::FastIgnore::Patterns.new(
          *patterns, from_file: from_file, format: format, root: root, allow: true, append: append
        )
      )
      self
    end

    def build
      @rule_set.build
    end

    private

    def walk
      build

      @walker || ::FastIgnore::Walkers::FileSystem
    end
  end
end
