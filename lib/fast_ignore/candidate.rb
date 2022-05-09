# frozen-string-literal: true

class FastIgnore
  class Candidate
    class << self
      def root
        @root ||= new('/', nil, true, true, nil)
      end

      def dir(dir)
        new(dir, nil, true, true, nil)
      end
    end

    def initialize(full_path, filename, directory, exists, content)
      @full_path = full_path
      @filename = filename
      (@directory = directory) unless directory.nil?
      (@exists = exists) unless exists.nil?
      (@first_line = content.slice(/.*/)) if content # we only care about the first line
    end

    def parent
      @parent ||= ::FastIgnore::Candidate.dir(::File.dirname(@full_path))
    end

    # use \0 because it can't be in paths
    def key
      @key ||= :"#{
        "\0" if defined?(@directory) && @directory
      }#{
        @full_path
      }\0#{
        @first_line if defined?(@first_line)
      }"
    end

    def relative_to(dir)
      return unless @full_path.start_with?(dir)

      ::FastIgnore::RelativeCandidate.new(@full_path.delete_prefix(dir), self)
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
      # :nocov:
    end

    def filename
      @filename ||= ::File.basename(@full_path)
    end

    # how long can a shebang be?
    # https://www.in-ulm.de/~mascheck/various/shebang/
    def first_line # rubocop:disable Metrics/MethodLength
      @first_line ||= begin
        file = ::File.new(@full_path)
        first_line = file.sysread(64)
        if first_line.start_with?('#!')
          first_line += file.readline unless first_line.include?("\n")
          file.close
          first_line
        else
          file.close
          ''
        end
      rescue ::EOFError, ::SystemCallError
        # :nocov:
        file&.close
        # :nocov:
        ''
      end
    end
  end
end
