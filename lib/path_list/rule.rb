# frozen_string_literal: true

class PathList
  class Rule
    def initialize
      @negated = false
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
      @start = :start_anchor unless @start == :no_anchor
    end

    def anchored?
      @start == :start_anchor
    end

    def never_anchored!
      @start = :no_anchor
    end

    def dir_only!
      @dir_only = true
    end

    def dir_only?
      @dir_only
    end

    def to_regexp
      # Regexp::IGNORECASE = 1
      Regexp.new("#{part_to_regexp(@start)}#{@parts.map { |part| part_to_regexp(part) }.join}", 1)
    end

    def compress_parts
      # [:character_class_open, single_non_slash_literal, :character_class_close] #> single_non_slash_literal
      # [:any_non_dir, *] => [:any_non_dir]
      #
    end

    def part_to_regexp(part)
      case part
      when :dir then '/'
      when :any_dir then '(?:.*/)?'
      when :one_non_dir then '[^/]'
      when :any_non_dir then '[^/]*'
      when :many_non_dir then '[^/]+'
      when :end_anchor then '\\z'
      when :start_anchor then '\\A'
      when :dir_or_start_anchor then '(?:\\A|/)'
      when :character_class_open then '(?!/)['
      when :character_class_negation then '^'
      when :character_class_dash then '-'
      when :character_class_close then ']'
      when :no_anchor then '(?:\\A|/)'
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
      @parts << :many_non_dir
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

      @parts << ::Regexp.escape(value)
    end
  end
end
