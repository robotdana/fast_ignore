# frozen-string-literal: true

class FastIgnore
  module Walkers
    class GitignoreCollectingFileSystem
      def initialize(rule_groups)
        @rule_groups = rule_groups
      end

      def allowed?(path, root: '.', directory: nil, content: nil, exists: nil, include_directories: false) # rubocop:disable Metrics/ParameterLists
        root = PathExpander.expand_dir(root)

        full_path = PathExpander.expand_path(path, root)
        return false unless full_path.start_with?(root)

        candidate = ::FastIgnore::Candidate.new(full_path, nil, directory, exists, content)

        return false if !include_directories && candidate.directory?
        return false unless candidate.exists?

        add_gitignore_to_root("#{::File.dirname(full_path)}/", root)
        @rule_groups.allowed_recursive?(candidate)
      end

      def each(parent_full_path, parent_relative_path, &block) # rubocop:disable Metrics/MethodLength
        children = ::Dir.children(parent_full_path)
        add_gitignore(parent_full_path) if children.include?('.gitignore')

        children.each do |filename|
          full_path = parent_full_path + filename
          candidate = ::FastIgnore::Candidate.new(full_path, filename, nil, true, nil)

          next unless @rule_groups.allowed_unrecursive?(candidate)

          relative_path = parent_relative_path + filename

          if candidate.directory?
            each(full_path + '/', relative_path + '/', &block)
          else
            yield(relative_path)
          end
        rescue ::Errno::ENOENT, ::Errno::EACCES, ::Errno::ENOTDIR, ::Errno::ELOOP, ::Errno::ENAMETOOLONG
          nil
        end
      end

      private

      def add_gitignore_to_root(path, root)
        add_gitignore(path)

        return if path == root

        add_gitignore_to_root("#{::File.dirname(path)}/", root)
      end

      def add_gitignore(dir)
        @rule_groups.append(:gitignore, ::FastIgnore::Patterns.new(from_file: "#{dir}.gitignore", root: dir))
      end
    end
  end
end
