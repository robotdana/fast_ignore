# frozen_string_literal: true

class PathList
  class PathRegexpBuilder
    def initialize
      @group_open_count = 0
      @string = +''
    end

    def to_regexp
      # Regexp::IGNORECASE = 1
      ::Regexp.new(@string, 1)
    end

    # String methods

    def dup
      out = super

      @string = @string.dup

      out
    end

    def to_str
      @string
    end
    alias_method :to_s, :to_str

    def empty?
      @string.empty?
    end

    def end_with?(str)
      @string.end_with?(str)
    end

    def append(value)
      @string.<<(value)

      self
    rescue FrozenError
      # :nocov:
      # the string seems to become inadvertently frozen in 2.6 with specific inputs
      # and i don't understand why
      # it seems like it's happening during the Regexp.new
      # for some reason that i don't understand
      @string = @string.dup
      append(value)
      # :nocov:
    end
    alias_method :<<, :append

    def prepend(value)
      @string.prepend(value)

      self
    rescue FrozenError
      # :nocov:
      # the string seems to become inadvertently frozen in 2.6 with specific inputs
      # and i don't understand why
      # it seems like it's happening during the Regexp.new
      # for some reason that i don't understand
      @string = @string.dup
      prepend(value)
      # :nocov:
    end

    # builder methods

    def append_escaped(value)
      return unless value

      append(::Regexp.escape(value))
    end

    def append_dir
      append('/')
    end

    def append_any_dir
      append('(?:.*/)?')
    end

    def append_one_non_dir
      append('[^/]')
    end

    def append_any_non_dir
      append_one_non_dir
      append('*')
    end

    def append_many_non_dir
      append_one_non_dir
      append('+')
    end

    def append_end_anchor
      append('\\z')
    end

    def append_group_open
      @group_open_count += 1
      append('(?:')
    end

    def append_group_close
      @group_open_count -= 1
      append(')')
    end

    def append_or
      append('|')
    end

    def append_group_close_all
      append_group_close while @group_open_count > 0
    end

    def append_start_anchor
      append('\\A')
    end

    def append_dir_or_start_anchor
      append('(?:\\A|/)')
    end

    def append_character_class_open
      append('(?!/)[')
    end

    def append_character_class_negation
      append('^')
    end

    def append_character_class_dash
      append('-')
    end

    def append_character_class_close
      append(']')
    end
  end
end
