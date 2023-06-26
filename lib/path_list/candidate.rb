# frozen_string_literal: true

class PathList
  class Candidate
    attr_reader :full_path
    attr_writer :first_line

    def self.build(full_path, directory, exists)
      new(
        full_path,
        directory,
        exists
      )
    end

    def initialize(full_path, directory, exists)
      @full_path = full_path
      @directory = directory
      @exists = exists
      @first_line = nil
      @prepend_path = nil
      @child_candidates = nil
      @children = nil
    end

    def full_path_downcase
      @full_path_downcase ||= @full_path.downcase
    end

    def prepend_path
      @prepend_path ||= @full_path == '/' ? '' : @full_path
    end

    def parent
      return @parent if defined?(@parent)

      @parent = begin
        return if @full_path == '/'

        self.class.new(::File.dirname(@full_path), true, true)
      end
    end

    def child_candidates
      @child_candidates ||= build_from_tree || children.map do |filename|
        Candidate.new("#{prepend_path}/#{filename}", nil, true)
      end
    end

    def children
      @children ||= @tree&.keys || ::Dir.children(@full_path)
    end

    def directory?
      return @directory unless @directory.nil?

      @directory = ::File.lstat(@full_path).directory?
    rescue ::Errno::ENOENT, ::Errno::EACCES, ::Errno::ENAMETOOLONG, ::Errno::ENOTDIR, ::Errno::EPERM
      @exists ||= false
      @directory = false
    end

    def exists?
      return @exists unless @exists.nil?

      @exists = ::File.exist?(@full_path)
    rescue ::Errno::EACCES, ::Errno::ELOOP, ::Errno::ENAMETOOLONG, Errno::EPERM
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
          if first_line.include?("\n")
            first_line.downcase
          else
            ::File.open(@full_path, &:readline).downcase
          end
        else
          ''
        end
      rescue ::EOFError, ::SystemCallError
        ''
      ensure
        file&.close
      end
    end

    attr_writer :tree

    private

    def build_from_tree
      @tree&.map do |child_name, grandchildren|
        if grandchildren
          c = self.class.new("#{prepend_path}/#{child_name}", true, true)
          c.tree = grandchildren
          c
        else
          self.class.new("#{prepend_path}/#{child_name}", false, true)
        end
      end
    end
  end
end
