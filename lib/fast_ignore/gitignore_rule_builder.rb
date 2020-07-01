# frozen_string_literal: true

class FastIgnore
  class GitignoreRuleBuilder # rubocop:disable Metrics/ClassLength
    def initialize(rule, negation, dir_only, file_path)
      @re = ::String.new
      @segment_re = ::String.new

      @s = ::StringScanner.new(rule)

      @dir_only = dir_only
      @file_path = (file_path if file_path && !file_path.empty?)
      @negation = negation
      @anchored = false
      @trailing_two_stars = false
    end

    def append(value)
      @segment_re << value
    end

    def append_escaped(value)
      append(::Regexp.escape(value))
    end

    def process_escaped_char
      append_escaped(@s.matched[1]) if @s.scan(/\\./)
    end

    def process_character_class
      return unless @s.skip(/\[/)

      append('[')
      process_character_class_body(false)
    end

    def process_negated_character_class
      return unless @s.skip(/\[\^/)

      append('[^')
      process_character_class_body(true)
    end

    def unmatchable_rule!
      throw :unmatchable_rule, []
    end

    def process_character_class_end
      return unless @s.skip(/\]/)

      unmatchable_rule! unless @has_characters_in_group

      append(']')
    end

    def process_character_class_body(negated_class) # rubocop:disable Metrics/MethodLength
      @has_characters_in_group = false
      until process_character_class_end
        if @s.eos?
          unmatchable_rule!
        elsif process_escaped_char
          @has_characters_in_group = true
        elsif @s.skip(%r{/})
          next unless negated_class

          @has_characters_in_group = true
          append('/')
        elsif @s.skip(/-/)
          @has_characters_in_group = true
          append('-')
        else @s.scan(%r{[^/\]\-]+})
             @has_characters_in_group = true
             append_escaped(@s.matched)
        end
      end
    end

    def process_star_star_slash
      return unless @s.skip(%r{\*{2,}/})

      process_slash('(?:.*/)?')
    end

    def process_star_slash
      return unless @s.skip(%r{\*/})

      process_slash('[^/]*/')
    end

    def process_no_star_slash
      return unless @s.skip(%r{/})

      process_slash('/')
    end

    def process_slash(append)
      @re << @segment_re
      @re << append
      @segment_re.clear
      @anchored = true
    end

    def process_stars
      append('[^/]*') if @s.scan(%r{\*+(?=[^*/])})
    end

    def process_question_mark
      append('[^/]') if @s.skip(/\?/)
    end

    def process_text
      append_escaped(@s.matched) if @s.scan(%r{[^*/?\[\\]+})
    end

    def process_star_end
      return unless @s.scan(/\*\z/)

      if @segment_re.empty? # at least something. this is to allow subdir negations to work
        append('[^/]+')
      else
        append('[^/]*')
      end
    end

    def process_two_star_end
      return unless @s.scan(/\*{2,}\z/)

      @trailing_two_stars = true
    end

    def process_trailing_backslash
      append_escaped('\\') if @s.skip(/\\$/)
    end

    def process_rule # rubocop:disable Metrics/AbcSize
      until @s.eos?
        process_escaped_char || process_trailing_backslash ||
          process_star_star_slash || process_star_slash || process_no_star_slash ||
          process_stars || process_question_mark ||
          process_negated_character_class || process_character_class ||
          process_text || process_star_end || process_two_star_end
      end
    end

    def prefix # rubocop:disable Metrics/MethodLength
      if @file_path
        if @anchored
          "\\A#{::Regexp.escape(@file_path)}"
        else
          "\\A#{::Regexp.escape(@file_path)}(?:.*/)?"
        end
      else
        if @anchored
          '\\A'
        else
          '(?:\\A|/)'
        end
      end
    end

    def build_rules
      (@re << '\\z') unless @trailing_two_stars

      # Regexp::IGNORECASE = 1
      ::FastIgnore::Rule.new(::Regexp.new(@re, 1), @negation, anchored_or_file_path, @dir_only)
    end

    def anchored_or_file_path
      @anchored || @file_path
    end

    def build
      @anchored = true if @s.skip(%r{/})

      catch :unmatchable_rule do
        process_rule

        @re << @segment_re

        @re.prepend(prefix)
        build_rules
      end
    end
  end
end
