# frozen_string_literal: true

require 'strscan'

class PathList
  class GitignoreRuleScanner < ::StringScanner
    def character_class_end?
      skip(/\]/)
    end

    def character_class_start?
      skip(/\[/)
    end

    def character_class_negation?
      skip(/\^|!/)
    end

    def slash?
      skip(%r{/})
    end

    def slash_end?
      skip(%r{/\s*\z})
    end

    def backslash?
      skip(/\\/)
    end

    def star_star_slash_end?
      skip(%r{\*{2,}/\s*\z})
    end

    def star_star_slash_slash?
      skip(%r{\*{2,}//})
    end

    def slash_slash?
      skip(%r{/{2}})
    end

    def star_star_slash?
      skip(%r{\*{2,}/})
    end

    def slash_star_star_end?
      skip(%r{/\*{2,}\s*\z})
    end

    def star?
      skip(/\*/)
    end

    def next_character
      matched if scan(/./)
    end

    def question_mark?
      skip(/\?/)
    end

    def character_class_literal
      matched if scan(/[^\]\\][^\]\\-]*(?!-)/)
    end

    def character_class_range_start
      matched if scan(/(\\.|[^\\\]])(?=-(\\.|[^\\\]]))/)
    end

    def character_class_range_end
      # we already confirmed this was going to match
      # with the lookahead in character_class_range_start
      skip(/-/)
      scan(/(\\.|[^\\\]])/)
      matched
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
