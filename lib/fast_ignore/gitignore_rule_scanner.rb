# frozen_string_literal: true

class FastIgnore
  class GitignoreRuleScanner < StringScanner
    def character_class_end?
      skip(/\]/)
    end

    def character_class_start?
      skip(/\[/)
    end

    def character_class_negation?
      skip(/\^|!/)
    end

    def end?
      skip(/\s*\z/)
    end

    def slash?
      skip(%r{/})
    end

    def backslash?
      skip(/\\/)
    end

    def two_stars?
      skip(/\*{2,}/)
    end

    def star?
      skip(/\*/)
    end

    def next_character
      matched if scan(/./)
    end

    def star_end?
      skip(/\*\s*\z/)
    end

    def question_mark?
      skip(/\?/)
    end

    def dash?
      skip(/-/)
    end

    def character_class_literal
      matched if scan(/[^\]\-\\]+/)
    end

    def literal
      matched if scan(%r{[^*/?\[\\\s]+})
    end

    def significant_whitespace
      matched if scan(/\s+(?!\s|\z)/)
    end

    def exclamation_mark?
      skip(/!/)
    end

    def hash?
      skip(/#/)
    end
  end
end
