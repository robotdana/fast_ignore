# frozen-string-literal: true

class FastIgnore
  module Walkers
    module FileSystem
      class << self
        def allowed?( # rubocop:disable Metrics/ParameterLists
          path,
          path_list:,
          directory: nil,
          content: nil,
          exists: nil,
          include_directories: false
        )
          full_path = PathExpander.expand_path(path)
          candidate = ::FastIgnore::Candidate.new(full_path, nil, directory, exists, content, path_list)
          return false if !include_directories && candidate.directory?
          return false unless candidate.exists?

          allowed_recursive?(candidate)
        end

        def each(parent_full_path, parent_relative_path, path_list, &block) # rubocop:disable Metrics/MethodLength
          ::Dir.children(parent_full_path).each do |filename|
            full_path = parent_full_path + filename
            candidate = ::FastIgnore::Candidate.new(full_path, filename, nil, true, nil, path_list)

            next unless path_list.rule_set.match?(candidate) == :allow

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

        def allowed_recursive?(candidate)
          return true unless candidate.parent

          allowed_recursive?(candidate.parent) && candidate.path_list.rule_set.match?(candidate) == :allow
        end
      end
    end
  end
end
