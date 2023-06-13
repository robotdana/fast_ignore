# frozen_string_literal: true

class PathList
  module Builders
    module FullPath
      def self.build(path, allow, _root)
        path = path.delete_prefix('/')
        if allow
          build_implicit(path)
        else
          Matchers::PathRegexp.build(/\A#{Regexp.escape(path)}\z/i, true, allow, true)
        end
      end

      def self.build_implicit(path) # rubocop:disable Metrics/MethodLength
        path_segments = path.split('/')
        re = PathRegexpBuilder.new
        re.append_start_anchor
        re.append_escaped(path_segments.shift)
        path_segments.each do |segment|
          re.append_group_open
          re.append_end_anchor
          re.append_or
          re.append_dir
          re.append_escaped(segment)
        end
        re.append_end_anchor
        re.append_group_close_all

        Matchers::PathRegexp.build(re.to_regexp, true, true, true)
      end
    end
  end
end
