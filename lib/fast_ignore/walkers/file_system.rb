# frozen-string-literal: true

class FastIgnore
  module Walkers
    module FileSystem
      def self.allowed?( # rubocop:disable Metrics/ParameterLists
        path,
        rule_set:,
        directory: nil,
        content: nil,
        exists: nil,
        include_directories: false
      )
        full_path = PathExpander.expand_path(path)
        candidate = ::FastIgnore::Candidate.new(full_path, nil, directory, exists, content)
        return false if !include_directories && candidate.directory?
        return false unless candidate.exists?

        rule_set.allowed_recursive?(candidate)
      end

      def self.each(parent_full_path, parent_relative_path, rule_set, &block) # rubocop:disable Metrics/MethodLength
        ::Dir.children(parent_full_path).each do |filename|
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
    end
  end
end
