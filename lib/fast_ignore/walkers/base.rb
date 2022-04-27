# frozen-string-literal: true

class FastIgnore
  module Walkers
    class Base
      def initialize(rule_groups, root:, relative:, follow_symlinks:)
        unless relative
          warn 'FastIgnore deprecation: yielding absolute paths (with relative: false or the default) is deprecated'
        end

        warn 'FastIgnore deprecation: follow_symlinks argument is deprecated' if follow_symlinks

        @root = root
        @relative = relative
        @follow_symlinks = follow_symlinks
        @rule_groups = rule_groups
      end

      private

      def prefixed_path(path)
        "#{@root unless @relative}#{path}"
      end

      def directory?(full_path, directory)
        if !directory.nil?
          directory
        elsif @follow_symlinks
          ::File.stat(full_path).directory?
        else
          ::File.lstat(full_path).directory?
        end
      end
    end
  end
end
