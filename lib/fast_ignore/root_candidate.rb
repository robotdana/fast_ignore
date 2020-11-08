# frozen-string-literal: true

class FastIgnore
  class RootCandidate
    attr_reader :full_path

    def initialize(full_path, filename, directory, content)
      @full_path = full_path
      @filename = filename
      (@directory = directory) unless directory.nil?
      @first_line = content
      @relative_to = {}
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
      @relative_to.fetch(dir) do
        @relative_to[dir] = build_candidate_relative_to(dir)
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
    # apparently cygwin 65536, and a limit is better than no limit
    def first_line # rubocop:disable Metrics/MethodLength
      @first_line ||= begin
        file = ::File.new(@full_path)
        first_line = new_fragment = file.sysread(64)
        if first_line.start_with?('#!')
          loops = 0
          until new_fragment.include?("\n") || loops == 1023
            new_fragment = file.sysread(64)
            first_line += new_fragment
            loops += 1
          end
        else
          file.close
          return
        end
        file.close
        first_line || ''
      rescue ::EOFError, ::SystemCallError
        # :nocov:
        file&.close
        # :nocov:
        first_line || ''
      end
    end

    private

    def build_candidate_relative_to(dir)
      relative_path = @full_path.dup.delete_prefix!(dir)
      return unless relative_path

      ::FastIgnore::RelativeCandidate.new(relative_path, self)
    end
  end
end
