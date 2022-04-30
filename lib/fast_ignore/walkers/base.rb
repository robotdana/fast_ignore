# frozen-string-literal: true

class FastIgnore
  module Walkers
    class Base
      def initialize(rule_groups, follow_symlinks:)
        warn 'FastIgnore deprecation: follow_symlinks argument is deprecated' if follow_symlinks

        @follow_symlinks = follow_symlinks
        @rule_groups = rule_groups
      end

      private

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
