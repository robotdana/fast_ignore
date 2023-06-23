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

      root += '/' unless root == '/'
      recursive_each(root, '', dir_matcher, file_matcher, &block)
    end

    private

    def recursive_each(parent_full_path, parent_relative_path, dir_matcher, file_matcher, &block) # rubocop:disable Metrics/MethodLength
      ::Dir.children(parent_full_path).each do |filename|
        full_path = "#{parent_full_path}#{filename}"
        candidate = Candidate.new(full_path, nil, true, nil)

        if candidate.directory?
          next unless dir_matcher.match(candidate) == :allow

          recursive_each("#{full_path}/", "#{parent_relative_path}#{filename}/", dir_matcher, file_matcher, &block)
        else
          next unless file_matcher.match(candidate) == :allow

          yield("#{parent_relative_path}#{filename}")
        end
      rescue ::Errno::ENOENT, ::Errno::EACCES, ::Errno::ENOTDIR, ::Errno::ELOOP, ::Errno::ENAMETOOLONG
        nil
      end
    end

    def recursive_match?(candidate, matcher)
      return true unless candidate

      recursive_match?(candidate.parent, matcher) && matcher.match(candidate) == :allow
    end
  end
end
