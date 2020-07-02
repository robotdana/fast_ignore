# frozen_string_literal: true

class FastIgnore
  class GitignoreRuleBuilder # rubocop:disable Metrics/ClassLength
    def initialize(rule, negation, dir_only, file_path)
      @re = ::String.new
      @s = ::StringScanner.new(rule)

      @dir_only = dir_only
      @file_path = file_path
      @negation = negation
      @anchored = false
    end

    def unmatchable_rule!
      throw :unmatchable_rule, []
    end

    def anchored!
      @anchored ||= true
    end

    def never_anchored!
      @anchored = :never
    end

    def emit(value)
      @re << value
    end

    def emit_escaped(value)
      emit(::Regexp.escape(value))
    end

    def backslash_escape?
      @s.scan(/\\./)
    end

    def emit_backslash_escape
      emit_escaped(@s.matched[1])
    end

    def emit_character_class_start
      emit('(?!/)[')
    end

    def emit_character_class_negation
      emit('^')
    end

    def character_class_start?
      @s.skip(/\[/)
    end

    def character_class_end?
      @s.skip(/\]/)
    end

    def character_class_negation?
      @s.skip(/(\^|!)/)
    end

    def string_end?
      @s.eos?
    end

    def character_class_range_operator?
      @s.skip(/-/)
    end

    def emit_character_class_range_operator
      emit('-')
    end

    def emit_match
      emit_escaped(@s.matched)
    end

    def character_class_literal?
      @s.scan(/[^\]\-\\]+/)
    end

    def emit_character_class_end
      emit(']')
    end

    def process_character_class # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      emit_character_class_start
      emit_character_class_negation if character_class_negation?
      unmatchable_rule! if character_class_end?

      until character_class_end?
        break unmatchable_rule! if string_end?
        break unmatchable_rule! if backslash_end?
        next emit_backslash_escape if backslash_escape?
        next emit_character_class_range_operator if character_class_range_operator?

        if character_class_literal?
          emit_match
        # :nocov:
        else
          # I'm pretty sure literal matches everything else
          # but in case i forgot anything don't endless loop
          # everything cov is not forgotten
          break unrecognized_character
          # :nocov:
        end
      end

      emit_character_class_end
    end

    def slash_star_star_slash_star_end?
      @s.skip(%r{/\*{2,}/\*\z})
    end

    def emit_slash
      anchored!
      emit('/')
    end

    def emit_slash_star_star_slash
      emit_slash
      emit_star_star_slash
    end

    def emit_star_star_slash
      emit('(?:.*/)?')
    end

    def emit_star_end_after_slash
      emit('[^/]+')
      emit_end_anchor
    end

    def emit_star
      emit('[^/]*')
    end

    def emit_slash_star_star_slash_star_end
      emit_slash_star_star_slash
      emit_star_end_after_slash
    end

    def slash_star_star_slash?
      @s.skip(%r{/\*{2,}/})
    end

    def star_star_slash_star_end?
      @s.skip(%r{\*{2,}/\*\z})
    end

    def emit_star_star_slash_star_end
      emit_star_star_slash
      emit_star_end_after_slash
    end

    def star_star_slash?
      @s.skip(%r{\*{2,}/})
    end

    def emit_leading_star_star_slash
      never_anchored!

      emit_leading_star_star_slash if star_star_slash?
    end

    def emit_leading_star_star_slash_star_end
      never_anchored!
      @anchored = :never
      emit_star_end_after_slash
    end

    def star_slash_star_end?
      @s.skip(%r{\*/\*\z})
    end

    def emit_star_slash_star_end
      emit_star_slash
      emit_star_end_after_slash
    end

    def star_slash?
      @s.skip(%r{\*/})
    end

    def emit_star_slash
      emit_star
      emit_slash
    end

    def slash?
      @s.skip(%r{/})
    end

    def slash_star_end?
      @s.skip(%r{/\*\z})
    end

    def emit_slash_star_end
      emit_slash
      emit_star_end_after_slash
    end

    def stars?
      @s.scan(/\*+/)
    end

    def question_mark?
      @s.skip(/\?/)
    end

    def emit_question_mark
      emit('[^/]')
    end

    def literal?
      @s.scan(%r{[^*/?\[\\]+})
    end

    def star_end?
      @s.scan(/\*\z/)
    end

    def emit_star_end
      emit_star
      emit_end_anchor
    end

    def star_star_end?
      @s.scan(/\*{2,}\z/)
    end

    def backslash_end?
      @s.skip(/\\\z/)
    end

    def emit_end_anchor
      emit('\\z')
    end

    def emit_star_star_end
      # intentionally left blank
    end

    # :nocov:
    def unrecognized_character
      raise "Unrecognized character '#{@s.peek(1)}' in rule '#{@s.string}'"
    end
    # :nocov:

    def process_rule # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      emit_leading_star_star_slash_star_end if star_star_slash_star_end?
      emit_leading_star_star_slash if star_star_slash?

      loop do
        break unmatchable_rule! if backslash_end?
        next emit_backslash_escape if backslash_escape?
        break emit_slash_star_star_slash_star_end if slash_star_star_slash_star_end?
        next emit_slash_star_star_slash if slash_star_star_slash?
        next emit_star_star_slash_star_end if star_star_slash_star_end?
        next emit_star_star_slash if star_star_slash?
        break emit_star_slash_star_end if star_slash_star_end?
        next emit_star_slash if star_slash?
        break emit_slash_star_end if slash_star_end?
        next emit_slash if slash?
        break emit_star_star_end if star_star_end?
        break emit_star_end if star_end?
        next emit_star if stars?
        next emit_question_mark if question_mark?
        next process_character_class if character_class_start?
        break emit_end_anchor if string_end?

        if literal?
          emit_match
        # :nocov:
        else
          # I'm pretty sure literal matches everything else
          # but in case i forgot anything don't endless loop
          # everything cov is not forgotten
          break unrecognized_character
          # :nocov:
        end
      end
    end

    def prefix # rubocop:disable Metrics/MethodLength
      if @file_path
        if @anchored
          "\\A#{@file_path.escaped}"
        else
          "\\A#{@file_path.escaped}(?:.*/)?"
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

        @re.prepend(prefix)
        build_rule
      end
    end
  end
end
