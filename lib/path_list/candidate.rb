# frozen_string_literal: true

class PathList
  class Candidate
    attr_reader :full_path
    attr_writer :first_line

    def initialize(full_path, directory = nil, first_line = nil)
      @full_path = full_path
      @full_path_downcase = nil
      @directory = directory
      @exists = nil
      @first_line = first_line

      @child_candidates = nil
      @children = nil
    end

    def full_path_downcase
      @full_path_downcase ||= @full_path.downcase
    end

    def parent
      return if @full_path == '/'

      self.class.new(::File.dirname(@full_path), true)
    end

    def child_candidates
      @child_candidates ||= begin
        prepend_path = @full_path == '/' ? '' : @full_path

        children.map { |filename| self.class.new("#{prepend_path}/#{filename}") }
      end
    end

    def children
      @children ||= ::Dir.children(@full_path)
    rescue ::SystemCallError
      @children = []
    end

    def directory?
      return @directory unless @directory.nil?

      @directory = ::File.lstat(@full_path).directory?
    rescue ::SystemCallError
      @exists ||= false
      @directory = false
    end

    def exists?
      return @exists unless @exists.nil?

      @exists = ::File.exist?(@full_path)
    rescue ::SystemCallError
      @exists = false
    end

    alias_method :original_inspect, :inspect # leftovers:keep

    def inspect
      "#<PathList::Candidate #{@full_path}#{'/' if directory?}>"
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
      rescue ::IOError, ::SystemCallError
        @exists ||= false
        ''
      ensure
        file&.close
      end
    end
  end
end
