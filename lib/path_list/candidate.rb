# frozen_string_literal: true

class PathList
  class Candidate
    attr_reader :full_path

    def self.build(full_path, directory, exists, content)
      new(
        full_path,
        directory,
        exists,
        (content && (content.slice(/\A#!.*/) || ''))
      )
    end

    def initialize(full_path, directory, exists, first_line)
      @full_path = full_path
      @directory = directory
      @exists = exists
      @first_line = first_line
    end

    def prepend_path
      @prepend_path ||= @full_path == '/' ? '' : @full_path
    end

    def parent
      return @parent if defined?(@parent)

      @parent = begin
        return if @full_path == '/'

        self.class.new(::File.dirname(@full_path), true, true, nil)
      end
    end

    def each_leaf(relative_root, git_indexes, dir_matcher, file_matcher, &block) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      if directory?
        return unless dir_matcher.match(self) == :allow

        if children.include?('.git') && (index = git_indexes.find { |i| i.index_root?(self) })
          @child_candidates = index.files.map do |relative_path|
            Candidate.new("#{prepend_path}/#{relative_path}", false, true, nil)
          end
          dir_matcher = dir_matcher.without_matcher(index)
          file_matcher = file_matcher.without_matcher(index)
        end

        child_candidates.each do |candidate|
          candidate.each_leaf(relative_root, git_indexes, dir_matcher, file_matcher, &block)
        end
      else
        return unless file_matcher.match(self) == :allow

        yield(@full_path.delete_prefix(relative_root))
      end
    rescue ::Errno::ENOENT, ::Errno::EACCES, ::Errno::ENOTDIR, ::Errno::ELOOP, ::Errno::ENAMETOOLONG
      nil
    end

    def child_candidates
      @child_candidates ||= children.map { |filename| Candidate.new("#{prepend_path}/#{filename}", nil, true, nil) }
    end

    def children
      @children ||= ::Dir.children(@full_path)
    end

    def filename
      @filename ||= ::File.basename(@full_path)
    end

    def directory?
      return @directory unless @directory.nil?

      @directory = ::File.lstat(@full_path).directory?
    rescue ::Errno::ENOENT, ::Errno::EACCES, ::Errno::ENAMETOOLONG, ::Errno::ENOTDIR
      @exists ||= false
      @directory = false
    end

    def exists?
      return @exists unless @exists.nil?

      @exists = ::File.exist?(@full_path)
    rescue ::Errno::EACCES, ::Errno::ELOOP, ::Errno::ENAMETOOLONG
      @exists = false
    end

    alias_method :original_inspect, :inspect # leftovers:keep

    def inspect
      "#<PathList::Candidate #{@full_path}>"
    end

    # how long can a shebang be?
    # https://www.in-ulm.de/~mascheck/various/shebang/
    # way too long
    # so we assume 64 characters probably,
    # but will grab the whole first line if it starts with hashbang chars.
    # we don't want to always just grab the first line regardless of length,
    # in case it's a binary or minified file
    def first_line # rubocop:disable Metrics/MethodLength
      @first_line ||= begin
        file = ::File.new(@full_path)
        first_line = file.sysread(64)
        if first_line.start_with?('#!')
          begin
            first_line += file.readline unless first_line.include?("\n")
          rescue ::EOFError, ::SystemCallError
            nil
          end
          first_line
        else
          ''
        end
      rescue ::EOFError, ::SystemCallError
        ''
      ensure
        file&.close
      end
    end
  end
end
