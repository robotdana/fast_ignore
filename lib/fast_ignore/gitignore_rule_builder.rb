# frozen_string_literal: true

class FastIgnore
  class GitignoreRuleBuilder # rubocop:disable Metrics/ClassLength
    def initialize(rule, file_path)
      @re = ::String.new
      @s = ::StringScanner.new(rule)

      @file_path = file_path
      @negation = false
      @anchored = false
      @dir_only = false
    end

    def negated!
      @negation = true
    end

    def blank!
      throw :abort_build, []
    end

    def unmatchable_rule!
      throw :abort_build, []
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

    def dir_only!
      @dir_only = true
    end

    def emit_escaped(value)
      emit(::Regexp.escape(value))
    end

    def character_class_end?
      @s.skip(/\]/)
    end

    def end?
      @s.skip(/\s*\z/)
    end

    def emit_match
      emit_escaped(@s.matched)
    end

    def emit_dir
      anchored!
      emit('/')
    end

    def emit_any_dir
      anchored!
      emit('(?:.*/)?')
    end

    def emit_any_non_dir
      emit_one_non_dir
      emit('*')
    end

    def emit_many_non_dir
      emit_one_non_dir
      emit('+')
    end

    def emit_one_non_dir
      emit('[^/]')
    end

    def slash?
      @s.skip(%r{/})
    end

    def emit_end_anchor
      emit('\\z')
      break!
    end

    def backslash?
      @s.skip(/\\/)
    end

    def break!
      throw :break
    end

    def emit_next_character
      return unless @s.scan(/./)

      emit_escaped(@s.matched)
    end

    def stars?
      @s.skip(/\*+/)
    end

    def star?
      @s.skip(/\*/)
    end

    def nothing_emitted?
      @re.empty?
    end

    def process_backslash
      return unless backslash?

      emit_next_character || unmatchable_rule!
    end

    def process_star_end_after_slash
      return true unless @s.skip(/\*\s*\z/)

      emit_many_non_dir
      emit_end_anchor
    end

    def process_slash
      return unless slash?

      if end?
        dir_only!
      elsif slash?
        unmatchable_rule!
      else
        emit_dir
        process_star_end_after_slash
      end
    end

    def process_star # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      return unless star?

      if stars?
        if slash?
          if end?
            emit_any_non_dir
            dir_only!
          elsif slash?
            unmatchable_rule!
          else
            if nothing_emitted? # rubocop:disable Metrics/BlockNesting
              never_anchored!
            else
              emit_any_dir
            end
            process_star_end_after_slash
          end
        elsif end?
          break!
        else
          emit_any_non_dir
        end
      else
        emit_any_non_dir
      end
    end

    def process_question_mark
      emit('[^/]') if @s.skip(/\?/)
    end

    def process_character_class_dash
      emit('-') if @s.skip(/-/)
    end

    def process_character_class_literal
      emit_match if @s.scan(/[^\]\-\\]+/)
    end

    def process_character_class_end
      emit(']') if character_class_end?
    end

    def process_character_class
      return unless @s.skip(/\[/)

      emit('(?!/)[')
      emit('^') if @s.skip(/\^|!/)
      unmatchable_rule! if character_class_end?

      until process_character_class_end
        process_backslash ||
          process_character_class_dash ||
          process_character_class_literal ||
          unmatchable_rule!
      end
    end

    def process_literal
      emit_match if @s.scan(%r{[^*/?\[\\\s]+})
    end

    def process_whitespace
      return unless @s.scan(/\s+/)

      last_match = @s.matched
      emit_escaped(last_match) unless end?
      true
    end

    def process_end
      blank! if nothing_emitted?

      emit_end_anchor
    end

    def process_rule # rubocop:disable Metrics/MethodLength
      anchored! if slash?

      catch :break do
        loop do
          process_backslash ||
            process_slash ||
            process_star ||
            process_question_mark ||
            process_character_class ||
            process_literal ||
            process_whitespace ||
            process_end
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
      catch :abort_build do
        blank! if @s.skip(/#/)
        negated! if @s.skip(/!/)
        process_rule

        @anchored = false if @anchored == :never

        @re.prepend(prefix)
        build_rule
      end
    end
  end
end
