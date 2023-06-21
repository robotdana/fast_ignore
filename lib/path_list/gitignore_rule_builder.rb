# frozen_string_literal: true

class PathList
  class GitignoreRuleBuilder # rubocop:disable Metrics/ClassLength
    def initialize(rule, expand_path_with: nil)
      @negated = false
      @unanchorable = false
      @dir_only = false
      @re = RegexpBuilder.new([:dir_or_start_anchor])
      @s = GitignoreRuleScanner.new(rule)

      @expand_path_with = expand_path_with
    end

    def break!
      throw :break
    end

    def blank!
      throw :abort_build, Matchers::Blank
    end

    def unmatchable_rule!
      throw :abort_build, Matchers::Blank
    end

    def negated!
      @negated = true
    end

    def unnegated!
      @negated = false
    end

    def negated?
      @negated
    end

    def dir_only!
      @dir_only = true
    end

    def dir_only?
      @dir_only
    end

    def anchored!
      @re.start = :start_anchor unless @unanchorable
    end

    def anchored?
      @re.start_with?(:start_anchor)
    end

    def never_anchored!
      @re.start = :dir_or_start_anchor
      @unanchorable = true
    end

    def nothing_emitted?
      @re.empty?
    end

    def emit_dir
      anchored!
      @re.append_part :dir
    end

    def emit_any_dir
      anchored!
      @re.append_part :any_dir
    end

    def emit_end
      @re.append_part :end_anchor
      break!
    end

    def process_backslash(builder = @re)
      return unless @s.backslash?

      builder.append_string(@s.next_character) || unmatchable_rule!
    end

    def process_star_end_after_slash # rubocop:disable Metrics/MethodLength
      if @s.star_end?
        @re.append_part :many_non_dir
        emit_end
      elsif @s.two_star_end?
        break!
      elsif @s.star_slash_end?
        @re.append_part :many_non_dir
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
          @re.append_part :any_non_dir
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
        @re.append_part :any_non_dir
      end
    end

    def process_character_class # rubocop:disable Metrics/MethodLength
      return unless @s.character_class_start?

      @character_class = RegexpBuilder.new([:character_class_non_slash_open])
      @character_class.append_part :character_class_negation if @s.character_class_negation?
      unmatchable_rule! if @s.character_class_end?

      until @s.character_class_end?
        next if process_character_class_range
        next if process_backslash(@character_class)
        next if @character_class.append_string(@s.character_class_literal)

        unmatchable_rule!
      end

      @character_class.append_part :character_class_close
      @re.append_unescaped @character_class.to_s(RegexpBuilder::CharacterClassBuilder)
    end

    def process_character_class_range
      start = @s.character_class_range_start
      return unless start

      start = start.delete_prefix('\\')

      @character_class.append_string(start)

      finish = @s.character_class_range_end.delete_prefix('\\')

      return true unless start < finish

      @character_class.append_part :character_class_dash
      @character_class.append_string(finish)
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
          next @re.append_part :any_non_dir if @s.star?
          next @re.append_part :one_non_dir if @s.question_mark?
          next if process_character_class
          next if @re.append_string(@s.literal)
          next if @re.append_string(@s.significant_whitespace)

          process_end
        end
      end
    end

    def build_matcher
      @re.compress

      matcher = Matchers::PathRegexp.build(@re, negated?)
      matcher = Matchers::MatchIfDir.build(matcher) if dir_only?
      matcher
    end

    def build
      catch :abort_build do
        blank! if @s.hash?
        negated! if @s.exclamation_mark?
        process_rule

        build_matcher
      end
    end

    def expand_rule_path!
      anchored! unless @s.match?(/\*/) # rubocop:disable Performance/StringInclude # it's StringScanner#match?
      return unless @s.match?(%r{(?:[~/]|\.{1,2}/|.*/\.\./)})

      dir_only! if @s.match?(%r{.*/\s*\z})

      new_rule = PathExpander.expand_path(@s.rest, @expand_path_with)
      new_rule.delete_prefix!(@expand_path_with)
      @s = GitignoreRuleScanner.new(new_rule)
    end
  end
end
