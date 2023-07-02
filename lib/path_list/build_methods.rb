# frozen_string_literal: true

require 'set'

class PathList
  module BuildMethods
    module ClassMethods
      def gitignore(root: nil, config: true)
        new.gitignore!(root: root, config: config)
      end

      def only(*patterns, read_from_file: nil, format: nil, root: nil)
        new.only!(*patterns, read_from_file: read_from_file, format: format, root: root)
      end

      def ignore(*patterns, read_from_file: nil, format: nil, root: nil)
        new.ignore!(*patterns, read_from_file: read_from_file, format: format, root: root)
      end
    end

    def gitignore(root: nil, config: true)
      dup.gitignore!(root: root, config: config)
    end

    def ignore(*patterns, read_from_file: nil, format: nil, root: nil)
      dup.ignore!(*patterns, read_from_file: read_from_file, format: format, root: root)
    end

    def only(*patterns, read_from_file: nil, format: nil, root: nil)
      dup.only!(*patterns, read_from_file: read_from_file, format: format, root: root)
    end

    def union(*path_lists)
      dup.union!(*path_lists)
    end

    def |(other)
      dup.union!(other)
    end

    def intersection(*path_lists)
      dup.intersection!(*path_lists)
    end

    def &(other)
      dup.intersection!(other)
    end

    def gitignore!(root: nil, config: true)
      and_matcher(Gitignore.build(root: root, config: config))

      self
    end

    def ignore!(*patterns, read_from_file: nil, format: nil, root: nil)
      and_matcher(Patterns.build(patterns, read_from_file: read_from_file, format: format, root: root).build)
    end

    def only!(*patterns, read_from_file: nil, format: nil, root: nil)
      and_matcher(
        Patterns.build(patterns, read_from_file: read_from_file, format: format, root: root, polarity: :allow).build
      )
    end

    def intersection!(*path_lists)
      and_matcher(Matchers::All.build(path_lists.map { |l| l.matcher })) # rubocop:disable Style/SymbolProc
    end

    def union!(*path_lists)
      self.matcher = Matchers::Any.build([@matcher, *path_lists.map { |l| l.matcher }]) # rubocop:disable Style/SymbolProc

      self
    end

    private

    def and_matcher(new_matcher)
      self.matcher = Matchers::All.build([@matcher, new_matcher])

      self
    end

    def matcher=(new_matcher)
      @matcher = new_matcher
      @dir_matcher = nil
      @file_matcher = nil
    end
  end
end
