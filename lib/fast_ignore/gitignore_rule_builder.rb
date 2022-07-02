# frozen_string_literal: true

class FastIgnore
  class GitignoreRuleBuilder # rubocop:disable Metrics/ClassLength
    def initialize(rule, expand_path_with: nil)
      @re = ::FastIgnore::PathRegexpBuilder.new
      @s = ::FastIgnore::GitignoreRuleScanner.new(rule)

      @expand_path_with = expand_path_with
      @negation = false
      @anchored = false
      @dir_only = false
    end

    def break!
      throw :break
    end

    def blank!
      throw :abort_build, []
    end

    def unmatchable_rule!
      throw :abort_build, []
    end

    def negated!
      @negation = true
    end

    def anchored!
      @anchored ||= true
    end

    def never_anchored!
      @anchored = :never
    end

    def dir_only!
      @dir_only = true
    end

    def nothing_emitted?
      @re.empty?
    end

    def emit_dir
      anchored!
      @re.append_dir
    end

    def emit_any_dir
      anchored!
      @re.append_any_dir
    end

    def emit_end
      @re.append_end_anchor
      break!
    end

    def process_backslash
      return unless @s.backslash?

      @re.append_escaped(@s.next_character) || unmatchable_rule!
    end

    def process_star_end_after_slash # rubocop:disable Metrics/MethodLength
      if @s.star_end?
        @re.append_many_non_dir
        emit_end
      elsif @s.two_star_end?
        break!
      elsif @s.star_slash_end?
        @re.append_many_non_dir
        dir_only!
        emit_end
      elsif @s.two_star_slash_end?
        dir_only!
        break!
      else
        true
      end
    end

    def process_slash
      return unless @s.slash?
      return dir_only! if @s.end?
      return unmatchable_rule! if @s.slash?

      emit_dir
      process_star_end_after_slash
    end

    def process_two_stars # rubocop:disable Metrics/MethodLength
      return unless @s.two_stars?
      return break! if @s.end?

      if @s.slash?
        if @s.end?
          @re.append_any_non_dir
          dir_only!
        elsif @s.slash?
          unmatchable_rule!
        else
          if nothing_emitted?
            never_anchored!
          else
            emit_any_dir
          end
          process_star_end_after_slash
        end
      else
        @re.append_any_non_dir
      end
    end

    def process_character_class # rubocop:disable Metrics/MethodLength
      return unless @s.character_class_start?

      @re.append_character_class_open
      @re.append_character_class_negation if @s.character_class_negation?
      unmatchable_rule! if @s.character_class_end?

      until @s.character_class_end?
        next if process_character_class_range
        next if process_backslash
        next if @re.append_escaped(@s.character_class_literal)

        unmatchable_rule!
      end

      @re.append_character_class_close
    end

    def process_character_class_range
      start = @s.character_class_range_start
      return unless start

      start = start.delete_prefix('\\')

      @re.append_escaped(start)

      finish = @s.character_class_range_end.delete_prefix('\\')

      return true unless start < finish

      @re.append_character_class_dash
      @re.append_escaped(finish)
    end

    def process_end
      blank! if nothing_emitted?

      emit_end
    end

    def process_rule # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      expand_rule_path! if @expand_path_with
      anchored! if @s.slash?

      catch :break do
        loop do
          next if process_backslash
          next if process_slash
          next if process_two_stars
          next @re.append_any_non_dir if @s.star?
          next @re.append_one_non_dir if @s.question_mark?
          next if process_character_class
          next if @re.append_escaped(@s.literal)
          next if @re.append_escaped(@s.significant_whitespace)

          process_end
        end
      end
    end

    def prefix
      out = ::FastIgnore::PathRegexpBuilder.new

      if @anchored
        out.append_start_anchor
      else
        out.append_dir_or_start_anchor
      end
      out
    end

    def build_rule
      @re.prepend(prefix)
      ::FastIgnore::Matchers::PathRegexp.new(@re.to_regexp, @anchored, @dir_only, @negation)
    end

    def build
      catch :abort_build do
        blank! if @s.hash?
        negated! if @s.exclamation_mark?
        process_rule

        @anchored = false if @anchored == :never

        build_rule
      end
    end

    def expand_rule_path!
      anchored! unless @s.match?(/\*/) # rubocop:disable Performance/StringInclude # it's StringScanner#match?
      return unless @s.match?(%r{(?:[~/]|\.{1,2}/|.*/\.\./)})

      dir_only! if @s.match?(%r{.*/\s*\z})

      @s.string.replace(PathExpander.expand_path(@s.rest, @expand_path_with))
      @s.string.delete_prefix!(@expand_path_with)
      @s.pos = 0
    end
  end
end
