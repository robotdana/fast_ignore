# frozen_string_literal: true

class PathList
  module QueryMethods
    include ::Enumerable

    def include?(path, directory: nil, content: nil, exists: nil)
      full_path = PathExpander.expand_path_pwd(path)
      candidate = Candidate.build(full_path, directory, exists)
      return false if candidate.directory?
      return false unless candidate.exists?

      candidate.first_line = content.slice(/\A#!.*$/).downcase || '' if content
      recursive_match?(candidate.parent, dir_matcher) &&
        file_matcher.match(candidate) == :allow
    end

    alias_method :member?, :include?

    def to_proc
      method(:include?).to_proc
    end

    def match?(path, directory: nil, content: nil, exists: nil)
      full_path = PathExpander.expand_path_pwd(path)
      candidate = Candidate.build(full_path, directory, exists)
      return false unless candidate.exists?

      candidate.first_line = content.slice(/\A#!.*$/).downcase || '' if content
      recursive_match?(candidate.parent, dir_matcher) &&
        matcher.match(candidate) == :allow
    end

    def ===(path)
      full_path = PathExpander.expand_path_pwd(path)
      candidate = Candidate.new(full_path, nil, nil)
      return false if candidate.directory?
      return false unless candidate.exists?

      recursive_match?(candidate.parent, dir_matcher) &&
        file_matcher.match(candidate) == :allow
    end

    def each(root = '.', &block)
      return enum_for(:each, root) unless block

      root = PathExpander.expand_path_pwd(root)
      root_candidate = Candidate.new(root, nil, nil)
      return unless recursive_match?(root_candidate.parent, dir_matcher)

      relative_root = root == '/' ? root : "#{root}/"

      if @git_indexes
        recursive_each_git_indexes(root_candidate, relative_root, @git_indexes, dir_matcher, file_matcher, &block)
      else
        recursive_each(root_candidate, relative_root, dir_matcher, file_matcher, &block)
      end
    end

    private

    def recursive_each(candidate, relative_root, dir_matcher, file_matcher, &block) # rubocop:disable Metrics/MethodLength
      if candidate.directory?
        return unless dir_matcher.match(candidate) == :allow

        candidate.child_candidates.each do |child|
          recursive_each(child, relative_root, dir_matcher, file_matcher, &block)
        end
      else
        return unless file_matcher.match(candidate) == :allow

        yield(candidate.full_path.delete_prefix(relative_root))
      end
    rescue ::Errno::ENOENT, ::Errno::EACCES, ::Errno::ENOTDIR, ::Errno::ELOOP, ::Errno::ENAMETOOLONG, Errno::EPERM
      nil
    end

    def recursive_each_git_indexes(candidate, relative_root, git_indexes, dir_matcher, file_matcher, &block) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      if candidate.directory?
        return unless dir_matcher.match(candidate) == :allow

        if candidate.children.include?('.git') && (index = git_indexes.find { |i| i.index_root?(candidate) })
          candidate.tree = index.file_tree
          dir_matcher = dir_matcher.without_matcher(index)
          file_matcher = file_matcher.without_matcher(index)
        end

        candidate.child_candidates.each do |child|
          recursive_each_git_indexes(child, relative_root, git_indexes, dir_matcher, file_matcher, &block)
        end
      else
        return unless file_matcher.match(candidate) == :allow

        yield(candidate.full_path.delete_prefix(relative_root))
      end
    rescue ::Errno::ENOENT, ::Errno::EACCES, ::Errno::ENOTDIR, ::Errno::ELOOP, ::Errno::ENAMETOOLONG, Errno::EPERM
      nil
    end

    def recursive_match?(candidate, matcher)
      return true unless candidate

      recursive_match?(candidate.parent, matcher) && matcher.match(candidate) == :allow
    end
  end
end
