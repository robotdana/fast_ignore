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

    def unmatchable_rule!
      throw :unmatchable_rule, []
    end

    def process_character_class # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      return unless @s.skip(/\[/)

      append('(?!/)[')
      append('^') if @s.skip(/(\^|!)/)

      unmatchable_rule! if @s.skip(/\]/)

      until @s.skip(/\]/)
        if @s.eos?
          unmatchable_rule!
        elsif process_escaped_char
        elsif @s.skip(/-/)
          append('-')
        elsif @s.scan(/[^\]\-\\]+/)
          append_escaped(@s.matched)
          # :nocov:
        else
          unrecognized_character
          # :nocov:
        end
      end

      append(']')
    end

    def process_slash_star_star_slash_star_end
      return unless @s.skip(%r{/\*{2,}/\*\z})

      process_slash('/(?:.*/)?')
      append('[^/]+')
    end

    def process_slash_star_star_slash
      return unless @s.skip(%r{/\*{2,}/})

      process_slash('/(?:.*/)?')
    end

    def process_star_star_slash_star_end
      return unless @s.skip(%r{\*{2,}/\*\z})

      process_slash('(?:.*/)?')
      append('[^/]+')
    end

    def process_star_star_slash
      return unless @s.skip(%r{\*{2,}/})

      process_slash('(?:.*/)?')
    end

    def process_leading_star_star_slash
      return unless @s.skip(%r{\*{2,}/})

      @anchored = :never

      process_leading_star_star_slash
    end

    def process_leading_star_star_slash_star_end
      return unless @s.skip(%r{\*{2,}/\*\z})

      @anchored = :never
      append('[^/]+')
    end

    def process_star_slash_star_end
      return unless @s.skip(%r{\*/\*\z})

      process_slash('[^/]*/')
      append('[^/]+')
    end

    def process_star_slash
      return unless @s.skip(%r{\*/})

      process_slash('[^/]*/')
    end

    def process_no_star_slash
      return unless @s.skip(%r{/})

      process_slash('/')
    end

    def process_no_star_slash_star_end
      return unless @s.skip(%r{/\*\z})

      process_slash('/')
      append('[^/]+')
    end

    def process_slash(append)
      @anchored ||= true

      @re << @segment_re
      @re << append
      @segment_re.clear
    end

    def process_stars
      append('[^/]*') if @s.scan(/\*+/)
    end

    def process_question_mark
      append('[^/]') if @s.skip(/\?/)
    end

    def process_text
      @s.scan(%r{[^*/?\[\\]+}) && append_escaped(@s.matched)
    end

    def process_star_end
      return unless @s.scan(/\*\z/)

      append('[^/]*')
    end

    def process_two_star_end
      return unless @s.scan(/\*{2,}\z/)

      @trailing_two_stars = true
    end

    def process_trailing_backslash
      unmatchable_rule! if @s.skip(/\\$/)
    end

    def process_end
      append('\\z')
    end

    def end_processed?
      @trailing_two_stars
    end

    # :nocov:
    def unrecognized_character
      raise "Unrecognized character '#{@s.peek(1)}' in rule '#{@rule}'"
    end
    # :nocov:

    def process_rule # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      process_leading_star_star_slash_star_end ||
        process_leading_star_star_slash

      until @s.eos?
        process_trailing_backslash ||
          process_escaped_char ||
          process_slash_star_star_slash_star_end ||
          process_slash_star_star_slash ||
          process_star_star_slash_star_end ||
          process_star_star_slash ||
          process_star_slash_star_end ||
          process_star_slash ||
          process_no_star_slash_star_end ||
          process_no_star_slash ||
          process_two_star_end ||
          process_star_end ||
          process_stars ||
          process_question_mark ||
          process_character_class ||
          process_text ||
          unrecognized_character
      end

      process_end unless end_processed?
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

    def build_rule
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
        @anchored = false if @anchored == :never

        @re << @segment_re

        @re.prepend(prefix)
        build_rule
      end
    end
  end
end
