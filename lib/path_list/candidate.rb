# frozen_string_literal: true

class PathList
  class Candidate
    attr_reader :full_path
    attr_writer :first_line
    attr_writer :tree

    def initialize(full_path, directory, exists, tree = nil)
      @full_path = full_path
      @full_path_downcase = nil
      @directory = directory
      @exists = exists
      @first_line = nil

      @child_candidates = nil
      @children = nil
      @tree = tree
    end

    def full_path_downcase
      @full_path_downcase ||= @full_path.downcase
    end

    def parent
      return if @full_path == '/'

      self.class.new(::File.dirname(@full_path), true, true)
    end

    def child_candidates
      @child_candidates ||= begin
        prepend_path = @full_path == '/' ? '' : @full_path

        @tree&.map do |child_name, grandchildren|
          if grandchildren
            self.class.new("#{prepend_path}/#{child_name}", true, true, grandchildren)
          else
            self.class.new("#{prepend_path}/#{child_name}", false, true)
          end
        end ||
          children.map { |filename| self.class.new("#{prepend_path}/#{filename}", nil, true) }
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
    def first_line
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
  end
end
