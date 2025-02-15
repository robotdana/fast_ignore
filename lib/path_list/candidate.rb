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

      @shebang = shebang

      @children = nil
      @ftype = nil
    end

    # @return [String] full path downcased
    def full_path_downcase
      @full_path_downcase ||= @full_path.downcase
    end

    # @return [Candidate, nil]
    #   the containing directory as a Candidate,
    #   or nil if this is already the root
    def parent
      return if @full_path.end_with?('/') # '/' on unix X:/ on win

      self.class.new(::File.dirname(@full_path), true)
    end

    # @return [Array<String>]
    #   the children of this as their filenames only. not full paths
    def children
      @children ||= begin
        ::Dir.children(@full_path)
      rescue ::IOError, ::SystemCallError
        []
      end
    end

    # @return [Boolean] whether this path is a directory (false for symlinks to directories)
    def directory?
      return @directory unless @directory.nil?

      @directory = ftype == 'directory'
    end

    # @return [Boolean] whether this path exists
    def exists?
      ftype != 'error'
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
        @ftype ||= 'error'
        ''
      ensure
        file&.close
      end
    end

    private

    # :nocov:
    # https://github.com/jruby/jruby/issues/8018
    # ftype follows symlinks on jruby on windows.
    if ::RUBY_PLATFORM == 'java' && ::RbConfig::CONFIG['host_os'].match?(/mswin|mingw/)
      # :nodoc:
      def ftype
        return @ftype if @ftype

        @ftype = if ::File.symlink?(@full_path)
          'link'
        else
          ::File.ftype(@full_path)
        end
      rescue ::IOError, ::SystemCallError
        @ftype = 'error'
      end
      # :nocov:
    else
      # :nodoc:
      def ftype
        return @ftype if @ftype

        @ftype = ::File.ftype(@full_path)
      rescue ::IOError, ::SystemCallError
        @ftype = 'error'
      end
    end
  end
end
