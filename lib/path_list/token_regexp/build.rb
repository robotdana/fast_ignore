# frozen_string_literal: true

class PathList
  class TokenRegexp
    module Build
      class << self
        def build_child_matcher(token_regexp); end

        def build_parent_matcher(token_regexp); end

        def build_path_matcher(token_regexp)
          if token_regexp.exact_path?
            Matchers::ExactString.build([token_regexp.to_s.downcase], @rule_polarity)
          else
            Matchers::PathRegexp.build([token_regexp.dup.compress.parts], @rule_polarity)
          end
        end

        def build(parts_arrays)
          if parts_arrays.length == 1
            build_from_array(parts_arrays.first)
          else
            build_from_hash(Merge.merge(parts_arrays))
          end
        end

        def build_from_array(parts_array)
          Regexp.new(parts_array.map { |p| PARTS_HASH[p] }.join)
        end

        def build_from_hash(parts_hash)
          Regexp.new(build_regexp_string_from_hash(parts_hash))
        end

        def build_literal_s(parts_array)
          return '' if parts_array.nil? || parts_array.empty?

          parts_array.map { |p| LITERAL_PARTS_HASH[p] }.join
        end

        def build_regexp_string_from_hash(parts_hash)
          return '' if parts_hash.nil? || parts_hash.empty?

          if parts_hash.length == 1
            part, tail = parts_hash.first
            "#{PARTS_HASH[part]}#{build_regexp_string_from_hash(tail)}"
          else
            parts = parts_hash.map { |k, v| [SORT_KEY[k], k, v] }.sort_by(&:first)
            "(?:#{parts.map { |(_, p, t)| "#{PARTS_HASH[p]}#{build_regexp_string_from_hash(t)}" }.join('|')})"
          end
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
          character_class_non_slash_open: '(?!/)[',
          character_class_negation: '^',
          character_class_dash: '-',
          character_class_close: ']',
          any_non_dot_non_dir: '[^\/\.]*',
          nil => ''
        }.tap { |h| h.default_proc = ->(_, k) { ::Regexp.escape(k).downcase } }.freeze

        private_constant :PARTS_HASH

        SORT_KEY = {
          dir: 1,
          any_dir: 10_000,
          any: 9999,
          one_non_dir: 1,
          any_non_dir: 9998,
          end_anchor: -2,
          start_anchor: -2,
          word_boundary: -1,
          character_class_non_slash_open: 2,
          character_class_negation: 0,
          character_class_dash: 0,
          character_class_close: 0,
          any_non_dot_non_dir: 9998,
          nil => 0
        }.tap { |h| h.default_proc = ->(_, k) { k.length } }.freeze

        private_constant :SORT_KEY
      end
    end
  end
end
