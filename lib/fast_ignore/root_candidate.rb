# frozen-string-literal: true

class FastIgnore
  class RootCandidate
    attr_reader :full_path

    def initialize(full_path, filename, directory, content)
      @full_path = full_path
      @filename = filename
      (@directory = directory) unless directory.nil?
      @first_line = content
    end

    def parent
      @parent ||= ::FastIgnore::RootCandidate.new(
        ::File.dirname(@full_path),
        nil,
        true,
        nil
      )
    end

    def relative_to(dir)
      return unless @full_path.start_with?(dir)

      ::FastIgnore::RelativeCandidate.new(@full_path.delete_prefix(dir), self)
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
    # 512 feels like a reasonable limit
    def first_line # rubocop:disable Metrics/MethodLength
      @first_line ||= begin
        file = ::File.new(@full_path)
        first_line = new_fragment = file.sysread(512)
        file.close
        first_line || ''
      rescue ::EOFError, ::SystemCallError
        # :nocov:
        file&.close
        # :nocov:
        first_line || ''
      end
    end
  end
end
