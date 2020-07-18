# frozen_string_literal: true

class FastIgnore
  class FileRoot
    # :nocov:
    using ::FastIgnore::Backports::DeletePrefixSuffix if defined?(::FastIgnore::Backports::DeletePrefixSuffix)
    # :nocov:

    def self.build(file_path, project_root)
      file_root = "#{::File.dirname(file_path)}/".delete_prefix(project_root)

      new(file_root) unless file_root.empty?
    end

    def initialize(file_root)
      @file_root = file_root
    end

    def shebang_path_pattern
      @shebang_path_pattern ||= /\A#{escaped}./
    end

    def escaped
      @escaped ||= ::Regexp.escape(@file_root)
    end

    def escaped_segments
      @escaped_segments ||= escaped.split('/')
    end

    def escaped_segments_length
      @escaped_segments_length ||= escaped_segments.length
    end

    def escaped_segments_joined
      @escaped_segments_joined ||= escaped_segments.join('(?:/') + '(?:/'
    end
  end
end
