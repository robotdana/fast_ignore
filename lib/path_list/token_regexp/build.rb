# frozen_string_literal: true

class PathList
  class TokenRegexp
    # @api private
    module Build
      class << self
        # @param parts_arrays [Array<Array<Symbol, String, EscapedString>>]
        # @return [Regexp]
        def build(parts_arrays, flags = 0)
          Regexp.new(
            if parts_arrays.length == 1
              parts_arrays.first.map { |p| PARTS_HASH[p] }.join
            else
              build_regexp_string_from_hash(Merge.merge(parts_arrays))
            end,
            flags
          )
        end

        # @param parts_array [Array<Symbol, String, EscapedString>]
        # @return [String]
        def build_literal_s(parts_array)
          parts_array.map { |p| LITERAL_PARTS_HASH[p] }.join
        end

        # @param parts_array [Array<Symbol, String, EscapedString>]
        # @return [EscapedString]
        def build_character_class(parts_array)
          EscapedString.new(parts_array.map { |p| CHARACTER_CLASS_PARTS_HASH[p] }.join)
        end

        private

        def build_regexp_string_from_hash(parts_hash)
          if parts_hash.length == 1
            part = parts_hash.keys.first
            tail = parts_hash[part]
            "#{PARTS_HASH[part]}#{tail && build_regexp_string_from_hash(tail)}"
          else
            parts = parts_hash.map { |k, v| [SORT_KEY[k], k, v] }
            parts.sort_by!(&:first)
            parts.map! { |(_, p, t)| "#{PARTS_HASH[p]}#{t && build_regexp_string_from_hash(t)}" }
            "(?:#{parts.join('|')})"
          end
        end

        LITERAL_PARTS_HASH = {
          dir: '/',
          end_anchor: '',
          start_anchor: '',
          nil => ''
        }
          .compare_by_identity
          .tap { |h| h.default_proc = ->(_, k) { k } }
          .freeze

        private_constant :LITERAL_PARTS_HASH

        CHARACTER_CLASS_PARTS_HASH = {
          character_class_non_slash_open: '(?!/)[',
          character_class_negation: '^',
          character_class_dash: '-',
          character_class_close: ']'
        }
          .compare_by_identity
          .tap { |h| h.default_proc = ->(_, k) { ::Regexp.escape(k) } }
          .freeze

        private_constant :CHARACTER_CLASS_PARTS_HASH

        PARTS_HASH = {
          dir: '/',
          any_dir: '(?:.*/)?',
          any: '.*',
          one_non_dir: '[^/]',
          any_non_dir: '[^/]*',
          end_anchor: '\\z',
          start_anchor: '\\A',
          word_boundary: '\\b',
          any_non_dot_non_dir: '[^\/\.]*',
          nil => ''
        }
          .tap do |h|
            h.default_proc = lambda { |_, k|
              if k.is_a?(EscapedString)
                k
              else
                ::Regexp.escape(k)
              end
            }
          end
          .freeze

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
          any_non_dot_non_dir: 9998,
          nil => 0
        }
          .tap { |h| h.default_proc = ->(_, k) { k.length } }
          .freeze

        private_constant :SORT_KEY
      end
    end
  end
end
