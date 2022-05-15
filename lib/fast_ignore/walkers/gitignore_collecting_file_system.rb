# frozen-string-literal: true

class FastIgnore
  module Walkers
    class GitignoreCollectingFileSystem
      def initialize(root, format: :gitignore, append: :gitignore)
        @append = append
        @format = format
        @root = PathExpander.expand_dir(root)
      end

      def allowed?(path, path_list:, directory: nil, content: nil, exists: nil, include_directories: false) # rubocop:disable Metrics/ParameterLists
        full_path = PathExpander.expand_path(path)
        candidate = ::FastIgnore::Candidate.new(full_path, nil, directory, exists, content)

        return false if !include_directories && candidate.directory?
        return false unless candidate.exists?

        add_gitignore_to_root(path_list, "#{::File.dirname(full_path)}/")

        path_list.rule_set.allowed_recursive?(candidate)
      end

      def each(parent_full_path, parent_relative_path, path_list, &block) # rubocop:disable Metrics/MethodLength
        children = ::Dir.children(parent_full_path)
        add_gitignore(path_list, parent_full_path) if children.include?('.gitignore')

        children.each do |filename|
          full_path = parent_full_path + filename
          candidate = ::FastIgnore::Candidate.new(full_path, filename, nil, true, nil)

          next unless path_list.rule_set.allowed_unrecursive?(candidate)

          relative_path = parent_relative_path + filename

          if candidate.directory?
            each(full_path + '/', relative_path + '/', path_list, &block)
          else
            yield(relative_path)
          end
        rescue ::Errno::ENOENT, ::Errno::EACCES, ::Errno::ENOTDIR, ::Errno::ELOOP, ::Errno::ENAMETOOLONG
          nil
        end
      end

      private

      def add_gitignore_to_root(path_list, dir)
        dirs = [dir]

        while dir != @root
          dir = "#{::File.dirname(dir)}/"
          dirs << dir
        end

        dirs.reverse_each do |new_root|
          path_list.ignore!(from_file: './.gitignore', root: new_root, append: @append, format: @format)
        end
        path_list.build
      end

      def add_gitignore(path_list, root)
        path_list.ignore!(from_file: './.gitignore', root: root, append: @append, format: @format)
        path_list.build
      end
    end
  end
end
