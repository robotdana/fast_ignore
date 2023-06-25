# frozen_string_literal: true

class PathList
  module QueryMethods
    include ::Enumerable

    def include?(path, directory: nil, content: nil, exists: nil)
      full_path = PathExpander.expand_path_pwd(path)
      candidate = Candidate.build(full_path, directory, exists, content)
      return false if candidate.directory?
      return false unless candidate.exists?

      recursive_match?(candidate.parent, dir_matcher) &&
        file_matcher.match(candidate) == :allow
    end

    alias_method :member?, :include?

    def to_proc
      method(:include?).to_proc
    end

    def match?(path, directory: nil, content: nil, exists: nil)
      full_path = PathExpander.expand_path_pwd(path)
      candidate = Candidate.build(full_path, directory, exists, content)
      return false unless candidate.exists?

      recursive_match?(candidate.parent, dir_matcher) &&
        (candidate.directory? ? dir_matcher : file_matcher).match(candidate) == :allow
    end

    def ===(path)
      full_path = PathExpander.expand_path_pwd(path)
      candidate = Candidate.new(full_path, nil, nil, nil)
      return false if candidate.directory?
      return false unless candidate.exists?

      recursive_match?(candidate.parent, dir_matcher) &&
        file_matcher.match(candidate) == :allow
    end

    def each(root = '.', &block)
      return enum_for(:each, root) unless block

      root = PathExpander.expand_path_pwd(root)
      root_candidate = Candidate.new(root, true, nil, nil)
      return unless root_candidate.directory?
      return unless recursive_match?(root_candidate.parent, dir_matcher)

      relative_root = root == '/' ? root : "#{root}/"
      root_candidate.each_leaf(relative_root, git_indexes, dir_matcher, file_matcher, &block)
    end

    private

    def recursive_match?(candidate, matcher)
      return true unless candidate

      recursive_match?(candidate.parent, matcher) && matcher.match(candidate) == :allow
    end
  end
end
