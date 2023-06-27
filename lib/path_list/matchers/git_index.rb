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
        matcher.match(candidate) if parent_re.match?(candidate.full_path_downcase)
      end

      def index_root?(candidate)
        @root == candidate.full_path_downcase
      end

      def file_tree # rubocop:disable Metrics/MethodLength
        @file_tree ||= begin
          tree_hash_proc = ->(h, k) { h[k] = Hash.new(&tree_hash_proc) }
          tree = Hash.new(&tree_hash_proc)
          PathList::GitIndex.files(@root).each do |path|
            if path.include?('/')
              *dirs, filename = path.split('/')
              tree.dig(*dirs).merge!(filename => nil)
            else
              tree[path] = nil
            end
          end
          tree.default = nil
          tree
        end
      end

      private

      def parent_re
        @parent_re ||= RegexpBuilder.new_from_path(@root, dir: nil).compress.to_regexp
      end

      def matcher
        @matcher ||= begin
          root_prefix = @root == '/' ? '' : @root.downcase
          dir_array, file_array = create_paths(file_tree, root_prefix)

          Matchers::LastMatch.build([
            Matchers::Ignore,
            Matchers::MatchIfDir.new(Matchers::ExactStringList.new(dir_array.sort, :allow)),
            Matchers::MatchUnlessDir.new(Matchers::ExactStringList.new(file_array.sort, :allow))
          ])
        end
      end

      def create_paths(file_tree, prefix) # rubocop:disable Metrics/MethodLength
        dir_array = []
        file_array = []
        file_tree.each do |filename, children|
          path = "#{prefix}/#{filename.downcase}"
          if children
            dir_array << path
            child_dir_array, child_file_array = create_paths(children, path)
            dir_array.concat(child_dir_array)
            file_array.concat(child_file_array)
          else
            file_array << path
          end
        end
        [dir_array, file_array]
      end
    end
  end
end
