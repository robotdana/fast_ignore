# frozen_string_literal: true

class FastIgnore
  class GitignoreRuleRegexpBuilder < String
    def to_regexp
      # Regexp::IGNORECASE = 1
      ::Regexp.new(self, 1)
    end

    def append(value)
      self.<<(value)

      self
    end

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

    def append_start_anchor
      append('\\A')
    end

    def append_start_dir_or_anchor
      append('(?:\\A|/)')
    end

    def append_end_dir_or_anchor
      append('(?:/|\\z)')
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
