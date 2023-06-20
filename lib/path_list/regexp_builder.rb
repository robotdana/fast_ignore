# frozen_string_literal: true

class PathList
  class RegexpBuilder # rubocop:disable Metrics/ClassLength
    def self.merge_parts_lists(parts_lists) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      merged = []

      return merged if parts_lists.empty?

      start_with_fork, start_with_value = parts_lists
        .partition { |parts_list| parts_list.first.is_a?(Array) }

      if start_with_value.empty?
        merged = merge_parts_lists(start_with_fork.flatten(1)) unless start_with_fork.empty?
      else
        grouped_by_first = start_with_value.group_by(&:first)

        if grouped_by_first.length == 1
          if grouped_by_first.first.first.nil?
            merged
          else
            merged = Array(grouped_by_first.first.first)
            # rubocop:disable Metrics/BlockNesting
            merged += merge_parts_lists(start_with_value.map { |parts_list| parts_list.drop(1) })
            merged = merge_parts_lists([merged] + start_with_fork.flatten(1)) unless start_with_fork.empty?
            # rubocop:enable Metrics/BlockNesting
          end
        else
          new_fork = []
          merged = [new_fork]

          grouped_by_first.each do |first_item, sub_parts_lists|
            if first_item.nil?
              new_fork << []
            else
              tail = Array(first_item)
              tail += merge_parts_lists(sub_parts_lists.map { |parts_list| parts_list.drop(1) })
              new_fork << tail
            end
          end

          merged = merge_parts_lists(new_fork.flatten(1) + start_with_fork.flatten(1)) unless start_with_fork.empty?
        end
      end

      merged
    end

    def initialize(parts = [])
      @parts = parts
      @unanchorable = false
      @character_class = nil
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

    def build_matcher(matcher_class, negated)
      re_string = @parts.map { |part| part_to_regexp(part) }.join
      return negated ? Matchers::Allow : Matchers::Ignore if re_string.empty?

      # Regexp::IGNORECASE = 1
      matcher_class.build(Regexp.new(re_string, 1), negated, @parts.dup.freeze)
    end

    START_COMPRESSION_RULES = {
      [:start_anchor, :any_non_dir, :end_anchor] => [:start_anchor, :one_non_dir], # fixing an issue with compressing this to nothing
      [:start_anchor, :any_dir] => [:dir_or_start_anchor],
      [:start_anchor, :any] => [],
      [:dir_or_start_anchor, :any] => [],
      [:dir_or_start_anchor, :any_non_dir] => [],
      [:dir_or_start_anchor, :many_non_dir] => [:one_non_dir],
      [:end_anchor_for_include] => [],
      [:end_anchor] => []
    }.freeze

    END_COMPRESSION_RULES = {
      [:any_dir, :end_anchor] => [],
      [:any, :end_anchor] => [],
      [:any_dir, :any_non_dir, :end_anchor] => [],
      [:start_anchor] => [],
      [:dir_or_start_anchor] => []
    }.freeze

    MID_COMPRESSION_RULES = {
      # needs to be the same length
      [:any_non_dir, :any_non_dir] => [nil, :any_non_dir],
      [:one_non_dir, :any_non_dir] => [nil, :many_non_dir],
      [:any_non_dir, :one_non_dir] => [nil, :many_non_dir],
      [:many_non_dir, :any_non_dir] => [nil, :many_non_dir],
      [:any_non_dir, :many_non_dir] => [nil, :many_non_dir],
      [:any_non_dir, :any_dir] => [nil, :any]
    }.freeze

    def compress # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      changed = false
      START_COMPRESSION_RULES.each do |rule, replacement|
        if rule == @parts.take(rule.length)
          @parts[0, rule.length] = replacement
          changed = true
        end
      end

      END_COMPRESSION_RULES.each do |rule, replacement|
        if rule == @parts.slice(-1 * rule.length, rule.length)
          @parts[-1 * rule.length, rule.length] = replacement
          # changed = true
        end
      end

      MID_COMPRESSION_RULES.each do |rule, replacement|
        @parts.each_cons(rule.length).with_index do |parts_cons, index|
          if rule == parts_cons
            @parts[index, rule.length] = replacement
            changed = true
          end
        end
        @parts.compact!
      end

      compress if changed
    end

    def ancestors
      prev_rule = []
      rules = []

      parts = @parts

      any_dir_index = parts.index(:any_dir)
      parts = parts[0, any_dir_index] + [:any, :dir] if any_dir_index

      parts.slice_before(:dir).to_a[0...-1].each do |chunk|
        prev_rule.concat(chunk)
        rules << self.class.new(prev_rule + [:end_anchor])
      end

      rules
    end

    def build_parents(negated = true) # rubocop:disable Metrics/MethodLength Metrics/AbcSize
      return Matchers::Blank if ancestors.empty?

      self.class.new(
        self.class.merge_parts_lists(ancestors.each(&:compress).map { |p| p.parts }) # rubocop:disable Style/SymbolProc it breaks with protected methods,
      ).build_matcher(Matchers::PathRegexp, negated)
    end

    def part_to_regexp(part) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
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
            part.first.map { |sub_part| part_to_regexp(sub_part) }.join
          else
            part_to_regexp(part.first)
          end
        else
          "(?:#{part.map { |sub_parts| sub_parts.map { |sub_part| part_to_regexp(sub_part) }.join }.join('|')})"
        end
      else raise "Unknown token #{part.inspect}"
      end
    end

    def character_class_part_to_regexp(part)
      case part
      when :character_class_open then '(?!/)['
      when :character_class_negation then '^'
      when :character_class_dash then '-'
      when :character_class_close then ']'
      when nil, String then part
      else raise "Unknown token #{token}"
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

    def remove_end_anchor_for_include
      @parts.pop if @parts[-1] == :end_anchor_for_include
    end

    def character_class_open
      @character_class = [:character_class_open]
    end

    def character_class_close
      @character_class << :character_class_close
      re_string = @character_class.map { |part| character_class_part_to_regexp(part) }.join
      @character_class = nil
      append(re_string)
    end

    def character_class_append(value)
      @character_class << value
    end

    def character_class_append_string(value)
      return unless value

      value = ::Regexp.escape(value)

      if @character_class[-1].is_a?(String)
        @character_class[-1] << value
      else
        @character_class << value
      end
    end

    def append(value)
      @parts << value
    end

    def append_string(value)
      return unless value

      value = ::Regexp.escape(value)

      if @parts[-1].is_a?(String)
        @parts[-1] << value
      else
        @parts << value
      end
    end

    protected

    attr_reader :parts
  end
end
