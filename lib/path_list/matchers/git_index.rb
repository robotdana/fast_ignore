# frozen_string_literal: true

require 'set'

class PathList
  module Matchers
    class GitIndex < Base
      def initialize(root)
        @root = root
        @root_downcase = root.downcase
        @files = nil
        @parent_re = %r{\A#{Regexp.escape(@root_downcase)}/}
        @matcher = nil
      end

      def match(candidate)
        if @parent_re.match?(candidate.full_path_downcase)
          matcher.match(candidate)
        else
          :allow
        end
      end

      def index_root?(candidate)
        @root_downcase == candidate.full_path_downcase
      end

      def file_tree
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

      def inspect
        "#{self.class}.new(#{@root.inspect}, #{matcher.inspect})"
      end

      def without_matcher(matcher)
        return Allow if matcher == self

        self
      end

      def ==(other)
        other.instance_of?(self.class) &&
          other.root_downcase == @root_downcase
      end

      protected

      attr_reader :root_downcase

      private

      def matcher
        @matcher ||= begin
          root_prefix = @root == '/' ? '' : @root.downcase
          dir_set = Set.new
          file_set = Set.new

          create_paths(file_tree, root_prefix, dir_set, file_set)

          LastMatch.build([
            Ignore,
            MatchIfDir.new(ExactString.build(dir_set, :allow)),
            MatchUnlessDir.new(ExactString.build(file_set, :allow))
          ])
        end
      end

      def create_paths(file_tree, prefix, dir_set, file_set)
        file_tree.each do |filename, children|
          path = "#{prefix}/#{filename.downcase}"
          if children
            dir_set << path
            create_paths(children, path, dir_set, file_set)
          else
            file_set << path
          end
        end
      end
    end
  end
end
