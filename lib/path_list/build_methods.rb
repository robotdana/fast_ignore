# frozen_string_literal: true

class PathList
  module BuildMethods
    module ClassMethods
      def gitignore(root: nil, index: true, config: true)
        new.gitignore!(root: root, index: index, config: config)
      end

      def only(*patterns, from_file: nil, format: nil, root: nil)
        new.only!(*patterns, from_file: from_file, format: format, root: root)
      end

      def ignore(*patterns, from_file: nil, format: nil, root: nil)
        new.ignore!(*patterns, from_file: from_file, format: format, root: root)
      end

      def all(*path_lists)
        new.all!(*path_lists)
      end

      def any(*path_lists)
        new.any!(*path_lists)
      end
    end

    def gitignore(root: nil, index: true, config: true)
      dup.gitignore!(root: root, index: index, config: config)
    end

    def ignore(*patterns, from_file: nil, format: nil, root: nil)
      dup.ignore!(*patterns, from_file: from_file, format: format, root: root)
    end

    def only(*patterns, from_file: nil, format: nil, root: nil)
      dup.only!(*patterns, from_file: from_file, format: format, root: root)
    end

    def any(*path_lists)
      dup.any!(*path_lists)
    end

    def all(*path_lists)
      dup.all!(*path_lists)
    end

    def gitignore!(root: nil, index: true, config: true)
      indexes_array = @git_indexes || []
      and_matcher(Gitignore.build(root: root, index: index, config: config, indexes_array: indexes_array))
      @git_indexes = indexes_array unless indexes_array.empty?

      self
    end

    def ignore!(*patterns, from_file: nil, format: nil, root: nil)
      and_matcher(Patterns.build(patterns, from_file: from_file, format: format, root: root).build)
    end

    def only!(*patterns, from_file: nil, format: nil, root: nil)
      and_matcher(Patterns.build(patterns, from_file: from_file, format: format, root: root, polarity: :allow).build)
    end

    def all!(*path_lists)
      and_matcher(Matchers::All.build(path_lists.flat_map { |l| l.matcher })) # rubocop:disable Style/SymbolProc
    end

    def any!(*path_lists)
      and_matcher(Matchers::Any.build(path_lists.flat_map { |l| l.matcher })) # rubocop:disable Style/SymbolProc
    end

    private

    def and_matcher(new_matcher)
      @matcher = Matchers::All.build([@matcher, new_matcher])
      @dir_matcher = nil
      @file_matcher = nil
      @prepared = nil

      self
    end
  end
end
