# frozen_string_literal: true

class PathList
  class Rule # rubocop:disable Metrics/ClassLength
    def initialize(parts = [:dir_or_start_anchor], negated = false)
      @negated = negated
      @unanchorable = false
      @dir_only = false
      @parts = parts
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
      @parts[0] = :start_anchor unless @unanchorable
    end

    def anchored?
      @parts[0] == :start_anchor
    end

    def never_anchored!
      @parts[0] = :dir_or_start_anchor
      @unanchorable = true
    end

    def dir_only!
      @dir_only = true
    end

    def dir_only?
      @dir_only
    end

    def build_path_matcher
      parts = compress_parts(@parts.dup)
      re_string = parts.map { |part| part_to_regexp(part) }.join
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

    def build_parents # rubocop:disable Metrics/MethodLength Metrics/AbcSize
      tail = []
      parent = nil
      head = tail
      @parts.each do |part|
        if part == :dir || part == :any_dir
          new_tail = []
          new_fork = [[:end_anchor_for_include], new_tail]
          tail << new_fork
          parent = new_fork
          tail = new_tail
        end
        tail << part
      end

      if parent
        parent.pop

        @parts = head
        build
      else
        Matchers::Blank
      end
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
      when nil, String then part
      when Array
        if part.length == 1
          part_to_regexp(part.first)
        else
          "(?:#{part.map { |sub_parts| sub_parts.map { |sub_part| part_to_regexp(sub_part) }.join }.join('|')})"
        end
      else raise 'Unknown token'
      end
    end

    def character_class_part_to_regexp(part)
      case part
      when :character_class_open then '(?!/)['
      when :character_class_negation then '^'
      when :character_class_dash then '-'
      when :character_class_close then ']'
      when nil, String then part
      else raise 'Unknown token'
      end
    end

    def empty?
      @parts == [:dir_or_start_anchor] || @parts == [:start_anchor]
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
      @character_class = [:character_class_open]
    end

    def append_character_class_negation
      @character_class << :character_class_negation
    end

    def append_character_class_close
      @character_class << :character_class_close
      re_string = @character_class.map { |part| character_class_part_to_regexp(part) }.join
      @character_class = nil
      @parts.append(re_string)
    end

    def append_character_class_dash
      @character_class << :character_class_dash
    end

    def append_escaped(value)
      return unless value

      append(::Regexp.escape(value))
    end

    def append(value)
      return unless value

      if @character_class
        @character_class << value
      elsif @parts[-1].is_a?(String)
        @parts[-1] << value
      else
        @parts << value
      end
    end
  end
end
