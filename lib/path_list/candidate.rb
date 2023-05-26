# frozen_string_literal: true

class PathList
  class Candidate
    class << self
      def dir(dir, path_list)
        new(dir, nil, true, true, nil, path_list, true)
      end
    end

    attr_reader :path_list
    attr_reader :full_path

    def initialize(full_path, filename, directory, exists, content, path_list, parent_if_directory) # rubocop:disable Metrics/ParameterLists
      @full_path = full_path
      @filename = filename
      (@directory = directory) unless directory.nil?
      (@exists = exists) unless exists.nil?
      (@first_line = content.slice(/.*/)) if content # we only care about the first line
      @path_was = []
      @path_list = path_list
      @parent_if_directory = parent_if_directory
    end

    def parent
      return @parent if defined?(@parent)

      @parent = if @full_path == '/'
        nil
      else
        self.class.dir(::File.dirname(@full_path), path_list)
      end
    end

    def parent?
      directory? && @parent_if_directory
    end

    def path
      @path ||= @full_path.delete_prefix('/')
    end

    # TODO: some kind of case folding
    def with_path_relative_to(dir)
      return unless @full_path.start_with?(dir)

      begin
        @path_was << (path)
        @path = @full_path.delete_prefix(dir)

        yield self
      ensure
        @path = @path_was.pop
      end
    end

    def directory?
      return @directory if defined?(@directory)

      @directory = ::File.lstat(@full_path).directory?
    rescue ::Errno::ENOENT, ::Errno::EACCES, ::Errno::ENAMETOOLONG
      @exists ||= false
      @directory = false
    end

    def exists?
      return @exists if defined?(@exists)

      @exists = ::File.exist?(@full_path)
    rescue ::Errno::EACCES, ::Errno::ELOOP, ::Errno::ENAMETOOLONG
      # :nocov: can't quite get this set up in a test
      @exists = false
      # :nocov: can't quite get this set up in a test
    end

    def filename
      @filename ||= ::File.basename(@full_path)
    end

    alias_method :original_inspect, :inspect # leftovers:keep

    def inspect
      "#<PathList::Candidate #{@full_path}>"
    end

    # how long can a shebang be?
    # https://www.in-ulm.de/~mascheck/various/shebang/
    def first_line # rubocop:disable Metrics/MethodLength
      @first_line ||= begin
        file = ::File.new(@full_path)
        first_line = file.sysread(64)
        if first_line.start_with?('#!')
          first_line += file.readline unless first_line.include?("\n")
          first_line
        else
          ''
        end
      rescue ::EOFError, ::SystemCallError
        ''
      ensure
        # :nocov: can't quite get this set up in a test
        file&.close
        # :nocov: can't quite get this set up in a test
      end
    end
  end
end
