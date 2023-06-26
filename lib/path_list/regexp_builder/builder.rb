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
          return '' if parts.nil? || parts.empty?

          options = parts.map { |key, value| "#{PARTS_HASH[key]}#{to_s(value)}" }
          options.length == 1 ? options.first : "(?:#{options.join('|')})"
        end

        PARTS_HASH = {
          dir: '/',
          any_dir: '(?:.*/)?',
          any: '.*',
          one_non_dir: '[^/]',
          any_non_dir: '[^/]*',
          end_anchor: '\\z',
          start_anchor: '\\A',
          word_boundary: '\\b',
          dir_or_start_anchor: '(?:\\A|/)',
          character_class_non_slash_open: '(?!/)[',
          character_class_negation: '^',
          character_class_dash: '-',
          character_class_close: ']',
          any_non_dot_non_dir: '[^\/\.]*',
          nil => ''
        }.tap { |h| h.default_proc = ->(_, k) { ::Regexp.escape(k) } }.freeze

        private_constant :PARTS_HASH
      end
    end
  end
end
