# frozen-string-literal: true

class FastIgnore
  module Walkers
    class GitignoreCollectingFileSystem
      def initialize(rule_groups)
        @rule_groups = rule_groups
      end

      def allowed?(path, root: nil, directory: nil, content: nil)
        full_path = ::File.expand_path(path, root)

        return false unless full_path.start_with?(root)
        return false if directory.nil? ? ::File.lstat(full_path).directory? : directory

        @rule_groups.add_gitignore_to_root(full_path)

        candidate = ::FastIgnore::RootCandidate.new(full_path, nil, directory, content)
        @rule_groups.allowed_recursive?(candidate)
      rescue ::Errno::ENOENT, ::Errno::EACCES, ::Errno::ENOTDIR, ::Errno::ELOOP, ::Errno::ENAMETOOLONG
        false
      end

      def each(parent_full_path, parent_relative_path, &block) # rubocop:disable Metrics/MethodLength
        children = ::Dir.children(parent_full_path)
        @rule_groups.add_gitignore(parent_full_path) if children.include?('.gitignore')

        children.each do |filename|
          begin
            full_path = parent_full_path + filename
            relative_path = parent_relative_path + filename
            dir = ::File.lstat(full_path).directory?
            candidate = ::FastIgnore::RootCandidate.new(full_path, filename, dir, nil)

            next unless @rule_groups.allowed_unrecursive?(candidate)

            if dir
              each(full_path + '/', relative_path + '/', &block)
            else
              yield relative_path
            end
          rescue ::Errno::ENOENT, ::Errno::EACCES, ::Errno::ENOTDIR, ::Errno::ELOOP, ::Errno::ENAMETOOLONG
            nil
          end
        end
      end
    end
  end
end
