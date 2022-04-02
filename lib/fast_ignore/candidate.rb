# frozen-string-literal: true

class FastIgnore
  class Candidate
    attr_reader :relative_path_to_root

    class << self
      def root
        @root ||= new(nil, '.', nil, true, nil)
      end
    end

    def initialize(full_path, relative_path_to_root, filename, directory, content)
      @full_path = full_path
      @relative_path_to_root = relative_path_to_root
      @filename = filename
      (@directory = directory) unless directory.nil?
      (@first_line = content.slice(/.*/)) if content # we only care about the first line
    end

    def parent
      @parent ||= ::FastIgnore::Candidate.new(
        ::File.dirname(@full_path),
        ::File.dirname(@relative_path_to_root),
        nil,
        true,
        nil
      )
    end

    # use \0 because it can't be in paths
    def for_comparison
      @for_comparison ||= "#{"\0" if @directory}#{@relative_path_to_root}\0#{@first_line}"
    end

    def eql?(other)
      for_comparison == other.for_comparison
    end
    alias_method :==, :eql?

    def hash
      @hash ||= for_comparison.hash
    end

    def directory?
      return @directory if defined?(@directory)

      @directory ||= ::File.directory?(@full_path)
    end

    def filename
      @filename ||= ::File.basename(@full_path)
    end

    # how long can a shebang be?
    # https://www.in-ulm.de/~mascheck/various/shebang/
    # apparently cygwin 65536
    def first_line # rubocop:disable Metrics/MethodLength
      return @first_line if defined?(@first_line)

      @first_line = begin
        file = ::File.new(@full_path)
        first_line = file.sysread(64)
        if first_line.start_with?('#!')
          first_line += file.readline unless first_line.include?("\n")
          file.close
          first_line
        else
          file.close
          nil
        end
      rescue ::EOFError, ::SystemCallError
        # :nocov:
        file&.close
        # :nocov:
        nil
      end
    end
  end
end
