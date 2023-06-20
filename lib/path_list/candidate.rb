# frozen_string_literal: true

class PathList
  class Candidate
    class << self
      def dir(dir)
        new(dir, nil, true, true, nil)
      end
    end

    attr_reader :full_path

    def initialize(full_path, filename, directory, exists, content)
      @full_path = full_path
      @filename = filename
      (@directory = directory) unless directory.nil?
      (@exists = exists) unless exists.nil?
      if content
        # we only care about the first line that might be a shebang
        (@first_line = content.slice(/\A#!.*/) || '')
      end
    end

    def parent
      return @parent if defined?(@parent)

      @parent = if @full_path == '/'
        nil
      else
        self.class.dir(::File.dirname(@full_path))
      end
    end

    def path
      @path ||= @full_path.delete_prefix('/')
    end

    def relative_to(dir, candidate_object = RelativeCandidate.allocate)
      return unless @full_path.start_with?(dir)

      candidate_object.reinitialize(self, @full_path.delete_prefix(dir), dir)
    end

    def directory?
      return @directory if defined?(@directory)

      @directory = ::File.lstat(@full_path).directory?
    rescue ::Errno::ENOENT, ::Errno::EACCES, ::Errno::ENAMETOOLONG, ::Errno::ENOTDIR
      @exists ||= false
      @directory = false
    end

    def exists?
      return @exists if defined?(@exists)

      @exists = ::File.exist?(@full_path)
    rescue ::Errno::EACCES, ::Errno::ELOOP, ::Errno::ENAMETOOLONG
      @exists = false
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
