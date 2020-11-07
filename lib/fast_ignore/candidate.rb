# frozen-string-literal: true

class FastIgnore
  class Candidate
    attr_reader :relative_path_to_root

    def initialize(full_path, relative_path_to_root, filename, directory, content)
      @full_path = full_path
      @relative_path_to_root = relative_path_to_root
      @filename = filename
      (@directory = directory) unless directory.nil?
      @first_line = content
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
  end
end
