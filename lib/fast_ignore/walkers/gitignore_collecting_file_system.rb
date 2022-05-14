# frozen-string-literal: true

class FastIgnore
  module Walkers
    module GitignoreCollectingFileSystem
      class << self
        def allowed?(path, rule_set:, directory: nil, content: nil, exists: nil, include_directories: false) # rubocop:disable Metrics/ParameterLists
          full_path = PathExpander.expand_path(path)
          candidate = ::FastIgnore::Candidate.new(full_path, nil, directory, exists, content)

          return false if !include_directories && candidate.directory?
          return false unless candidate.exists?

          add_gitignore_to_root(rule_set, "#{::File.dirname(full_path)}/")

          rule_set.allowed_recursive?(candidate)
        end

        def each(parent_full_path, parent_relative_path, rule_set, &block) # rubocop:disable Metrics/MethodLength
          children = ::Dir.children(parent_full_path)
          add_gitignore(rule_set, parent_full_path) if children.include?('.gitignore')

          children.each do |filename|
            full_path = parent_full_path + filename
            candidate = ::FastIgnore::Candidate.new(full_path, filename, nil, true, nil)

            next unless rule_set.allowed_unrecursive?(candidate)

            relative_path = parent_relative_path + filename

            if candidate.directory?
              each(full_path + '/', relative_path + '/', rule_set, &block)
            else
              yield(relative_path)
            end
          rescue ::Errno::ENOENT, ::Errno::EACCES, ::Errno::ENOTDIR, ::Errno::ELOOP, ::Errno::ENAMETOOLONG
            nil
          end
        end

        private

        def add_gitignore_to_root(rule_set, path)
          rule_set.append_until_root(:gitignore, from_file: './.gitignore', dir: path)
        end

        def add_gitignore(rule_set, dir)
          rule_set.append(:gitignore, from_file: "#{dir}.gitignore", root: dir)
        end
      end
    end
  end
end
