# frozen_string_literal: true

class PathList
  module Matchers
    class GitIndex < Base
      def initialize(root)
        @root = root
        @root_re = nil
        @files = nil
      end

      def match(candidate)
        matcher.match(candidate) if parent_re.match?(candidate.full_path)
      end

      def files
        @files ||= PathList::GitIndex.files(@root)
      end

      def index_root?(candidate)
        root_re.match?(candidate.full_path)
      end

      private

      def root_re
        @root_re ||= RegexpBuilder.new_from_path(@root).compress.to_regexp
      end

      def parent_re
        @parent_re ||= RegexpBuilder.new_from_path(@root, dir: nil).compress.to_regexp
      end

      def matcher # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        @matcher ||= begin
          root_prefix = @root == '/' ? @root.downcase : "#{@root.downcase}/"

          file_array = files.map { |relative_path| "#{root_prefix}#{relative_path}".downcase }.sort
          dir_array = file_array.flat_map { |relative_path| relative_path.sub(%r{/[^/]*\z}, '') }.uniq
          last_dir_array = dir_array

          loop do
            new_dir_array = last_dir_array.map { |relative_path| relative_path.sub(%r{/[^/]*\z}, '') }.uniq
            dir_array += new_dir_array
            break unless new_dir_array.any? { |dir| dir.include?('/') }

            last_dir_array = new_dir_array
          end

          dir_array.delete('')
          dir_array.push('/')
          dir_array = dir_array.sort

          Matchers::LastMatch.build([
            Matchers::Ignore,
            Matchers::MatchIfDir.new(Matchers::AllowInSortedArray.new(dir_array)),
            Matchers::MatchUnlessDir.new(Matchers::AllowInSortedArray.new(file_array))
          ])
        end
      end
    end
  end
end
