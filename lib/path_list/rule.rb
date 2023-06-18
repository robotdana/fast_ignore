# frozen_string_literal: true

class PathList
  class Rule # rubocop:disable Metrics/ClassLength
    def initialize
      @negated = false
      @unanchorable = false
      @dir_only = false
      @start = :dir_or_start_anchor
      @parts = []
    end

    def negated!
      @negated = true
    end

    def unnegated!
      @negated = false
    end

    def negated?
      @negated
    end

    def anchored!
      @start = :start_anchor unless @unanchorable
    end

    def anchored?
      @start == :start_anchor
    end

    def never_anchored!
      @start = :dir_or_start_anchor
      @unanchorable = true
    end

    def dir_only!
      @dir_only = true
    end

    def dir_only?
      @dir_only
    end

    def build_path_matcher
      re_string = compress_parts([@start, *@parts]).map { |part| part_to_regexp(part) }.join
      return negated? ? Matchers::Allow : Matchers::Ignore if re_string.empty?

      # Regexp::IGNORECASE = 1
      Matchers::PathRegexp.build(Regexp.new(re_string, 1), anchored?, negated?)
    end

    def build
      dir_only? ? Matchers::MatchIfDir.build(build_path_matcher) : build_path_matcher
    end

    START_COMPRESSION_RULES = {
      [:start_anchor, :any_dir] => [:any_non_dir],
      [:start_anchor, :any] => [],
      [:dir_or_start_anchor, :any] => [],
      [:dir_or_start_anchor, :any_non_dir] => [],
      [:end_anchor_for_include] => [],
      [:end_anchor] => []
    }.freeze

    END_COMPRESSION_RULES = {
      [:any_dir, :end_anchor] => [],
      [:dir, :any_non_dir, :end_anchor] => [],
      [:dir_or_start_anchor, :any_non_dir, :end_anchor] => [],
      [:start_anchor, :any_non_dir, :end_anchor] => [],
      [:start_anchor] => [],
      [:dir_or_start_anchor] => []
    }.freeze

    MID_COMPRESSION_RULES = {
      # needs to be the same length
      [:any_non_dir, :any_non_dir] => [nil, :any_non_dir],
      [:one_non_dir, :any_non_dir] => [:any_non_dir, :one_non_dir]
    }.freeze

    def compress_parts(parts) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      changed = false
      START_COMPRESSION_RULES.each do |rule, replacement|
        if rule == parts.take(rule.length)
          parts[0, rule.length] = replacement
          changed = true
        end
      end

      END_COMPRESSION_RULES.each do |rule, replacement|
        if rule == parts.slice(-1 * rule.length, rule.length)
          parts[-1 * rule.length, rule.length] = replacement
          # changed = true
        end
      end

      MID_COMPRESSION_RULES.each do |rule, replacement|
        parts.each_cons(rule.length).with_index do |parts_cons, index|
          if rule == parts_cons
            parts[index, rule.length] = replacement
            changed = true
          end
        end
        parts.compact!
      end

      return parts unless changed

      compress_parts(parts)
    end

    def part_to_regexp(part) # rubocop:disable Metrics/MethodLength
      case part
      when :dir then '/'
      when :any_dir then '(?:.*/)?'
      when :any then '.*'
      when :one_non_dir then '[^/]'
      when :any_non_dir then '[^/]*'
      when :end_anchor, :end_anchor_for_include then '\\z'
      when :start_anchor then '\\A'
      when :dir_or_start_anchor then '(?:\\A|/)'
      when :character_class_open then '(?!/)['
      when :character_class_negation then '^'
      when :character_class_dash then '-'
      when :character_class_close then ']'
      when nil, String then part
      else raise 'Unknown token'
      end
    end

    def empty?
      @parts.empty?
    end

    def dup
      out = super

      @parts = @parts.dup

      out
    end

    def end_with?(part)
      @parts[-1] == part
    end

    def append_dir
      @parts << :dir
    end

    def append_any_dir
      @parts << :any_dir
    end

    def append_end_anchor_for_include
      @parts << :end_anchor_for_include
    end

    def append_end_anchor
      @parts << :end_anchor
    end

    def append_any_non_dir
      @parts << :any_non_dir
    end

    def append_one_non_dir
      @parts << :one_non_dir
    end

    def append_many_non_dir
      @parts << :any_non_dir
      @parts << :one_non_dir
    end

    def append_character_class_open
      @parts << :character_class_open
    end

    def append_character_class_negation
      @parts << :character_class_negation
    end

    def append_character_class_close
      @parts << :character_class_close
    end

    def append_character_class_dash
      @parts << :character_class_dash
    end

    def append_escaped(value)
      return unless value

      if @parts[-1].is_a?(String)
        @parts[-1] << ::Regexp.escape(value)
      else
        @parts << ::Regexp.escape(value)
      end
    end
  end
end
