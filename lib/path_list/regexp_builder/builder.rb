# frozen_string_literal: true

class PathList
  class RegexpBuilder
    module Builder
      class << self
        def to_regexp(parts)
          re_string = to_regexp_s(parts)
          return if re_string.empty?

          Regexp.new(re_string)
        end

        def to_regexp_s(parts)
          return '' if parts.nil? || parts.empty?

          if parts.length == 1
            part, tail = parts.first
            "#{PARTS_HASH[part]}#{to_regexp_s(tail)}"
          else
            "(?:#{parts.map { |p, t| "#{PARTS_HASH[p]}#{to_regexp_s(t)}" }.join('|')})"
          end
        end

        def to_literal_s(parts)
          return '' if parts.nil? || parts.empty?

          key, value = parts.first
          "#{LITERAL_PARTS_HASH[key]}#{to_literal_s(value)}"
        end

        LITERAL_PARTS_HASH = {
          dir: '/',
          end_anchor: '',
          start_anchor: '',
          nil => ''
        }.tap { |h| h.default_proc = ->(_, k) { k.downcase } }.freeze

        private_constant :LITERAL_PARTS_HASH

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
        }.tap { |h| h.default_proc = ->(_, k) { ::Regexp.escape(k).downcase } }.freeze

        private_constant :PARTS_HASH
      end
    end
  end
end
