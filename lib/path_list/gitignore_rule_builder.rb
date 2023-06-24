# frozen_string_literal: true

class PathList
  class GitignoreRuleBuilder # rubocop:disable Metrics/ClassLength
    def initialize(rule, root: nil, allow: false, expand_path: false)
      @s = GitignoreRuleScanner.new(rule)
      @allow = allow
      @expand_path = expand_path
      @root = root

      @negated = @allow
      @unanchorable = false
      @dir_only = false
      @emitted = false
    end

    def prepare_regexp_builder
      @tail = @start_tail = { dir: { any_dir: nil } }
      @tail_part = :any_dir

      @re = if @root && @root != '/'
        RegexpBuilder.new_from_path(@root, @start_tail)
      else
        RegexpBuilder.new(start_anchor: @start_tail)
      end
    end

    def break!
      throw :break
    end

    def blank!
      throw :abort_build, Matchers::Blank
    end

    def unmatchable_rule!
      throw :abort_build, (@allow ? Matchers::Invalid : Matchers::Blank)
    end

    def negated!
      @negated = !@allow
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
      @anchored ||= begin
        @start_tail[:dir] = @start_tail.dig(:dir, :any_dir)
        @re.forget_tail
        true
      end
    end

    def anchored?
      @anchored
    end

    def nothing_emitted?
      !@emitted
    end

    def emitted!
      @emitted = true
    end

    def append_part(part)
      emitted!
      @re.append_part part
    end

    def append_string(string)
      emitted! if @re.append_string string
    end

    def append_unescaped(re_string)
      emitted! if @re.append_unescaped re_string
    end

    def emit_dir
      anchored!
      append_part :dir
    end

    def emit_any_dir
      anchored!
      append_part :any_dir
    end

    def emit_end
      append_part :end_anchor
      break!
    end

    def process_backslash(builder = @re)
      return unless @s.backslash?

      if builder.append_string(@s.next_character)
        emitted!
      else
        unmatchable_rule!
      end
    end

    def process_slash
      return unless @s.slash?
      return dir_only! if @s.end?
      return unmatchable_rule! if @s.slash?

      emit_dir
    end

    def process_slash_and_stars; end

    def process_two_stars # rubocop:disable Metrics/MethodLength
      return unless @s.two_stars?
      return break! if @s.end?

      if @s.slash?
        return unmatchable_rule! if @s.slash?

        if @s.end?
          dir_only!
        else
          emit_any_dir
        end
      else
        append_part :any_non_dir
      end

      true
    end

    def process_character_class # rubocop:disable Metrics/MethodLength
      return unless @s.character_class_start?

      @character_class = RegexpBuilder.new({ character_class_non_slash_open: nil })
      @character_class.append_part :character_class_negation if @s.character_class_negation?
      unmatchable_rule! if @s.character_class_end?

      until @s.character_class_end?
        next if process_character_class_range
        next if process_backslash(@character_class)
        next if @character_class.append_string(@s.character_class_literal)

        unmatchable_rule!
      end

      @character_class.append_part :character_class_close
      append_unescaped @character_class.to_s(RegexpBuilder::CharacterClassBuilder)
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
      prepare_regexp_builder
      expand_rule_path! if @expand_path

      anchored! if @s.slash?

      catch :break do
        loop do
          next if process_backslash
          next unmatchable_rule! if @s.star_star_slash_slash?
          next append_part(:any) && dir_only! if @s.star_star_slash_end?
          next append_part(:any_dir) && anchored! if @s.star_star_slash?
          next unmatchable_rule! if @s.slash_slash?
          next append_part(:dir) && append_part(:any) && anchored! if @s.slash_star_star_end?
          next append_part(:any_non_dir) if @s.star?
          next dir_only! if @s.slash_end?
          next append_part(:dir) && anchored! if @s.slash?
          next append_part(:one_non_dir) if @s.question_mark?
          next if process_character_class
          next if append_string(@s.literal)
          next if append_string(@s.significant_whitespace)

          process_end
        end
      end
    end

    def build_matcher
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

    def build_parent_matcher
      if anchored? || @root != '/'
        ancestors = @re.ancestors
        return Matchers::Blank if ancestors.empty?

        Matchers::MatchIfDir.build(Matchers::PathRegexp.build(ancestors, negated?))
      else
        Matchers::AllowAnyDir
      end
    end

    def build_child_matcher
      @child_re.replace_tail(:dir)
      Matchers::PathRegexp.build(@child_re, true)
    end

    def build_implicit
      catch :abort_build do
        blank! unless @allow

        blank! if @s.hash?
        blank! if @s.exclamation_mark?
        process_rule
        build_implicit_matcher
      end
    end

    def build_implicit_matcher
      @child_re ||= @re.dup

      Matchers::Any.build([
        build_parent_matcher,
        build_child_matcher
      ])
    end

    def expand_rule_path!
      will_be_anchored = true unless @s.match?(/\*/) # rubocop:disable Performance/StringInclude # it's StringScanner#match?
      return will_be_anchored && anchored! unless @s.match?(%r{(?:[~/]|\.{1,2}/|.*/\.\./)})

      dir_only! if @s.match?(%r{.*/\s*\z})

      new_rule = PathExpander.expand_path(@s.rest, @root).delete_prefix('/')
      @root = '/'
      prepare_regexp_builder
      anchored! if will_be_anchored
      @s = GitignoreRuleScanner.new(new_rule)
    end
  end
end
