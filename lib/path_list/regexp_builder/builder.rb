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
          return '' if parts.empty?

          options = parts.map { |key, value| "#{build_part(key)}#{build_part(value)}" }
          options.length == 1 ? options.first : "(?:#{options.join('|')})"
        end

        private

        def build_part(part) # rubocop:disable Metrics/MethodLength
          case part
          when :dir then '/'
          when :any_dir then '(?:.*/)?'
          when :any then '.*'
          when :one_non_dir then '[^/]'
          when :any_non_dir then '[^/]*'
          when :many_non_dir then '[^/]+'
          when :end_anchor then '\\z'
          when :start_anchor then '\\A'
          when :word_boundary then '\\b'
          when :dir_or_start_anchor then '(?:\\A|/)'
          when nil, String then part
          when Hash then to_s(part)
          else raise "Unknown token #{part.inspect}"
          end
        end
      end
    end
  end
end
