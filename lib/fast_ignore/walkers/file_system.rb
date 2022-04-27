# frozen-string-literal: true

class FastIgnore
  module Walkers
    class FileSystem < Base
      def allowed?(path, directory: nil, content: nil, exists: nil, include_directories: false) # rubocop:disable Metrics/MethodLength
        full_path = PathExpander.expand_path(path, @root)
        return false unless full_path.start_with?(@root)

        begin
          dir = directory?(full_path, directory)
        rescue ::Errno::ENOENT, ::Errno::EACCES, ::Errno::ELOOP, ::Errno::ENAMETOOLONG
          nil
        end

        return false if !include_directories && dir

        candidate = ::FastIgnore::Candidate.new(full_path, nil, dir, exists, content)

        return false unless candidate.exists?

        @rule_groups.allowed_recursive?(candidate)
      end

      def each(parent_full_path, parent_relative_path, &block) # rubocop:disable Metrics/MethodLength
        ::Dir.children(parent_full_path).each do |filename|
          full_path = parent_full_path + filename
          dir = directory?(full_path, nil)
          candidate = ::FastIgnore::Candidate.new(full_path, filename, dir, true, nil)

          next unless @rule_groups.allowed_unrecursive?(candidate)

          relative_path = parent_relative_path + filename

          if dir
            each(full_path + '/', relative_path + '/', &block)
          else
            yield(relative_path)
          end
        rescue ::Errno::ENOENT, ::Errno::EACCES, ::Errno::ENOTDIR, ::Errno::ELOOP, ::Errno::ENAMETOOLONG
          nil
        end
      end
    end
  end
end
