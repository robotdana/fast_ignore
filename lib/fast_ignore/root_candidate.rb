# frozen-string-literal: true

class FastIgnore
  class RootCandidate
    module RootDir
      def for_comparison
        "\0.\0"
      end

      def eql?(other)
        "\0.\0" == other.for_comparison
      end
      alias_method :==, :eql?

      def hash
        "\0.\0".hash
      end

      def relative_candidate(_)
        self
      end
    end

    def initialize(full_path, filename, directory, content)
      @full_path = full_path
      @filename = filename
      (@directory = directory) unless directory.nil?
      (@first_line = content.slice(/.*/)) if content # we only care about the first line
      @relative_candidate = {}
    end

    def parent
      @parent ||= ::FastIgnore::RootCandidate.new(
        ::File.dirname(@full_path),
        nil,
        true,
        nil
      )
    end

    # use \0 because it can't be in paths
    def for_comparison
      @for_comparison ||= "#{"\0" if @directory}#{@full_path}\0#{@first_line}"
    end

    def eql?(other)
      for_comparison == other.for_comparison
    end
    alias_method :==, :eql?

    def hash
      @hash ||= for_comparison.hash
    end

    def relative_candidate(relative_to)
      @relative_candidate.fetch(relative_to) do
        @relative_candidate[relative_to] = build_candidate_relative_to(relative_to)
      end
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

    private

    def build_candidate_relative_to(relative_to)
      relative_path = @full_path.dup.delete_prefix!(relative_to)
      return unless relative_path

      ::FastIgnore::RelativeCandidate.new(relative_path, self)
    end
  end
end
