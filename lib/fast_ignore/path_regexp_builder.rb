# frozen_string_literal: true

class FastIgnore
  class PathRegexpBuilder < String
    def to_regexp
      # Regexp::IGNORECASE = 1
      ::Regexp.new(self, 1)
    end

    def append_escaped(value)
      return unless value

      append_unescaped(::Regexp.escape(value))
    end

    def append_dir
      append_unescaped('/')
    end

    def append_any_dir
      append_unescaped('(?:.*/)?')
    end

    def append_one_non_dir
      append_unescaped('[^/]')
    end

    def append_any_non_dir
      append_one_non_dir
      append_unescaped('*')
    end

    def append_many_non_dir
      append_one_non_dir
      append_unescaped('+')
    end

    def append_end_anchor
      append_unescaped('\\z')
    end

    def append_start_anchor
      append_unescaped('\\A')
    end

    def append_dir_or_start_anchor
      append_unescaped('(?:\\A|/)')
    end

    def append_dir_or_end_anchor
      append_unescaped('(?:/|\\z)')
    end

    def append_character_class_open
      append_unescaped('(?!/)[')
    end

    def append_character_class_negation
      append_unescaped('^')
    end

    def append_character_class_dash
      append_unescaped('-')
    end

    def append_character_class_close
      append_unescaped(']')
    end

    private

    def append_unescaped(value)
      self.<<(value)

      self
    end
  end
end
