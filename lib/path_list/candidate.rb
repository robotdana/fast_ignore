# frozen_string_literal: true

class PathList
  # @api private
  # The object that gets passed to all {PathList::Matcher} subclasses #match
  class Candidate
    attr_reader :full_path

    # @param full_path [String] resolved absolute path
    # @param directory [Boolean, nil] override whether this is a directory
    # @param shebang [String, nil] override the shebang
    def initialize(full_path, directory = nil, shebang = nil)
      @full_path = full_path
      @full_path_downcase = nil
      @directory = directory
      @exists = nil
      @shebang = shebang

      @child_candidates = nil
      @children = nil
    end

    # @return [String] full path downcased
    def full_path_downcase
      @full_path_downcase ||= @full_path.downcase
    end

    # @return [Candidate, nil]
    #   the containing directory as a Candidate,
    #   or nil if this is already the root
    def parent
      puts "#{__FILE__}:#{__LINE__}, @full_path: #{@full_path}"
      return if @full_path.end_with?('/') # '/' on unix X:/ on win

      puts "#{__FILE__}:#{__LINE__}, ::File.dirname(@full_path): #{::File.dirname(@full_path)}"
      self.class.new(::File.dirname(@full_path), true)
    end

    # @return [Array<Candidate>]
    #   the children of this as Candidates
    def child_candidates
      @child_candidates ||= begin
        prepend_path = @full_path.end_with?('/') ? @full_path : "#{@full_path}/"

        children.map { |filename| self.class.new("#{prepend_path}#{filename}") }
      end
    end

    # @return [Array<String>]
    #   the children of this as their filenames only. not full paths
    def children
      @children ||= begin
        ::Dir.children(@full_path)
      rescue ::SystemCallError
        []
      end
    end

    # @return [Boolean] whether this path is a directory (false for symlinks to directories)
    def directory?
      return @directory unless @directory.nil?

      @directory = ::File.lstat(@full_path).directory?
    rescue ::SystemCallError
      @exists ||= false
      @directory = false
    end

    # @return [Boolean] whether this path exists
    def exists?
      return @exists unless @exists.nil?

      @exists = ::File.exist?(@full_path)
    rescue ::SystemCallError
      @exists = false
    end

    alias_method :original_inspect, :inspect # leftovers:keep

    # @return [String]
    def inspect
      "#<PathList::Candidate #{@full_path}#{'/' if directory?}>"
    end

    # @return [String] the first line of the file if it starts with #!
    def shebang
      @shebang ||= begin
        # how long can a shebang be?
        # https://www.in-ulm.de/~mascheck/various/shebang/
        # way too long
        # so we assume 64 characters probably,
        # but will grab the whole first line if it starts with hashbang chars.
        # we don't want to always just grab the first line regardless of length,
        # in case it's a binary or minified file
        file = ::File.new(@full_path)
        first_line = file.sysread(64)
        if first_line.start_with?('#!')
          if first_line.include?("\n")
            first_line
          else
            ::File.open(@full_path, &:readline)
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
