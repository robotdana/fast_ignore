# frozen_string_literal: true

class PathList
  class GitignoreRuleBuilder # rubocop:disable Metrics/ClassLength
    def initialize(rule, expand_path_with: nil)
      @rule = Rule.new
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
      @rule.negated!
    end

    def anchored!
      @rule.anchored!
    end

    def never_anchored!
      @rule.never_anchored!
    end

    def dir_only!
      @rule.dir_only!
    end

    def nothing_emitted?
      @rule.empty?
    end

    def emit_dir
      @rule.anchored!
      @rule.append_dir
    end

    def emit_any_dir
      @rule.anchored!
      @rule.append_any_dir
    end

    def emit_end
      @rule.append_end_anchor
      break!
    end

    def process_backslash
      return unless @s.backslash?

      @rule.append_escaped(@s.next_character) || unmatchable_rule!
    end

    def process_star_end_after_slash # rubocop:disable Metrics/MethodLength
      if @s.star_end?
        @rule.append_many_non_dir
        emit_end
      elsif @s.two_star_end?
        break!
      elsif @s.star_slash_end?
        @rule.append_many_non_dir
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
      return @rule.dir_only! if @s.end?
      return unmatchable_rule! if @s.slash?

      emit_dir
      process_star_end_after_slash
    end

    def process_two_stars # rubocop:disable Metrics/MethodLength
      return unless @s.two_stars?
      return break! if @s.end?

      if @s.slash?
        if @s.end?
          @rule.append_any_non_dir
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
        @rule.append_any_non_dir
      end
    end

    def process_character_class # rubocop:disable Metrics/MethodLength
      return unless @s.character_class_start?

      @rule.append_character_class_open
      @rule.append_character_class_negation if @s.character_class_negation?
      unmatchable_rule! if @s.character_class_end?

      until @s.character_class_end?
        next if process_character_class_range
        next if process_backslash
        next if @rule.append_escaped(@s.character_class_literal)

        unmatchable_rule!
      end

      @rule.append_character_class_close
    end

    def process_character_class_range
      start = @s.character_class_range_start
      return unless start

      start = start.delete_prefix('\\')

      @rule.append_escaped(start)

      finish = @s.character_class_range_end.delete_prefix('\\')

      return true unless start < finish

      @rule.append_character_class_dash
      @rule.append_escaped(finish)
    end

    def process_end
      blank! if nothing_emitted?

      emit_end
    end

    def process_rule # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      expand_rule_path! if @expand_path_with
      @rule.anchored! if @s.slash?

      catch :break do
        loop do
          next if process_backslash
          next if process_slash
          next if process_two_stars
          next @rule.append_any_non_dir if @s.star?
          next @rule.append_one_non_dir if @s.question_mark?
          next if process_character_class
          next if @rule.append_escaped(@s.literal)
          next if @rule.append_escaped(@s.significant_whitespace)

          process_end
        end
      end
    end

    def build_rule
      m = Matchers::PathRegexp.build(@rule.to_regexp, @rule.anchored?, @rule.negated?)
      m = Matchers::MatchIfDir.build(m) if @rule.dir_only?
      m
    end

    def build
      catch :abort_build do
        blank! if @s.hash?
        negated! if @s.exclamation_mark?
        process_rule

        build_rule
      end
    end

    def expand_rule_path!
      @rule.anchored! unless @s.match?(/\*/) # rubocop:disable Performance/StringInclude # it's StringScanner#match?
      return unless @s.match?(%r{(?:[~/]|\.{1,2}/|.*/\.\./)})

      @rule.dir_only! if @s.match?(%r{.*/\s*\z})

      new_rule = PathExpander.expand_path(@s.rest, @expand_path_with)
      new_rule.delete_prefix!(@expand_path_with)
      @s = GitignoreRuleScanner.new(new_rule)
    end
  end
end
