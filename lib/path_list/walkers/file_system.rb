# frozen_string_literal: true

class PathList
  module Walkers
    module FileSystem
      class << self
        def include?(
          path,
          path_list:,
          directory: nil,
          content: nil,
          exists: nil,
          as_parent: false
        )
          full_path = PathExpander.expand_path_pwd(path)
          candidate = Candidate.new(full_path, nil, directory, exists, content)
          return false if !as_parent && candidate.directory?
          return false unless candidate.exists?

          match_recursive?(candidate, path_list)
        end

        def each(parent_full_path, parent_relative_path, path_list, &block) # rubocop:disable Metrics/MethodLength
          ::Dir.children(parent_full_path).each do |filename|
            full_path = parent_full_path + filename
            candidate = Candidate.new(full_path, filename, nil, true, nil)

            next unless path_list.matcher.match(candidate) == :allow

            relative_path = parent_relative_path + filename
            if candidate.directory?
              each("#{full_path}/", "#{relative_path}/", path_list, &block)
            else
              yield(relative_path)
            end
          rescue ::Errno::ENOENT, ::Errno::EACCES, ::Errno::ENOTDIR, ::Errno::ELOOP, ::Errno::ENAMETOOLONG
            nil
          end
        end

        private

        def match_recursive?(candidate, path_list)
          return true unless candidate.parent

          match_recursive?(candidate.parent, path_list) && path_list.matcher.match(candidate) == :allow
        end
      end
    end
  end
end
