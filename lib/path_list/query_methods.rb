# frozen_string_literal: true

class PathList
  module QueryMethods
    include ::Enumerable

    def include?(path, directory: nil, content: nil, exists: nil)
      Walkers::FileSystem.include?(
        path,
        matcher: @matcher,
        directory: directory,
        content: content,
        exists: exists
      )
    end

    alias_method :member?, :include?

    def match?(path, directory: nil, content: nil, exists: nil)
      Walkers::FileSystem.include?(
        path,
        matcher: @matcher,
        directory: directory,
        content: content,
        exists: exists,
        as_parent: true
      )
    end

    def ===(path)
      Walkers::FileSystem.include?(path, matcher: @matcher)
    end

    def to_proc
      method(:include?).to_proc
    end

    def each(root = '.', &block)
      return enum_for(:each, root) unless block
      return unless Walkers::FileSystem.include?(root, matcher: @matcher, as_parent: true)

      Walkers::FileSystem.each(PathExpander.expand_dir_pwd(root), '', @matcher, &block)
    end
  end
end
