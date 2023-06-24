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
      return unless recursive_match?(root_candidate, dir_matcher)

      root = '' if root == '/'
      root_candidate.children.each do |filename|
        recursive_each("#{root}/#{filename}", filename, dir_matcher, file_matcher, &block)
      end
    end

    private

    def recursive_each(full_path, relative_path, dir_matcher, file_matcher, &block) # rubocop:disable Metrics/MethodLength
      candidate = Candidate.new(full_path, nil, true, nil)
      if candidate.directory?
        return unless dir_matcher.match(candidate) == :allow

        candidate.children.each do |filename|
          recursive_each("#{full_path}/#{filename}", "#{relative_path}/#{filename}", dir_matcher, file_matcher, &block)
        end
      else
        return unless file_matcher.match(candidate) == :allow

        yield(relative_path)
      end
    rescue ::Errno::ENOENT, ::Errno::EACCES, ::Errno::ENOTDIR, ::Errno::ELOOP, ::Errno::ENAMETOOLONG
      nil
    end

    def recursive_match?(candidate, matcher)
      return true unless candidate

      recursive_match?(candidate.parent, matcher) && matcher.match(candidate) == :allow
    end
  end
end
