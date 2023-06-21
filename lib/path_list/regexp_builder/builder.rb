# frozen_string_literal: true

class PathList
  class RegexpBuilder
    class Builder
      class << self
        def to_regexp(parts)
          re_string = to_s(parts)
          return if re_string.empty?

          # Regexp::IGNORECASE = 1
          Regexp.new(re_string, 1)
        end

        def to_s(parts)
          parts.map { |part| build_part(part) }.join
        end

        private

        def build_part(part) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
          case part
          when :dir then '/'
          when :any_dir then '(?:.*/)?'
          when :any then '.*'
          when :one_non_dir then '[^/]'
          when :any_non_dir then '[^/]*'
          when :many_non_dir then '[^/]+'
          when :end_anchor, :end_anchor_for_include then '\\z'
          when :start_anchor then '\\A'
          when :dir_or_start_anchor then '(?:\\A|/)'
          when nil, String then part
          when Array
            if part.length == 1
              if part.first.is_a?(Array)
                to_s(part.first)
              else
                build_part(part.first)
              end
            else
              "(?:#{part.map { |sub_parts| to_s(sub_parts) }.join('|')})"
            end
          else raise "Unknown token #{part.inspect}"
          end
        end
      end
    end
  end
end
