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
      initial_pattern = if @root == '/'
        [:start_anchor, :dir, :any_dir]
      elsif @root
        [:start_anchor, :dir] + @root.delete_prefix('/').split('/').flat_map { |segment| [Regexp.escape(segment), :dir] } + [:any_dir]
      else
        [:dir_or_start_anchor]
      end

      @re = RegexpBuilder.new(initial_pattern)
      @start_index = initial_pattern.length - 1
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

    def start_anchor
      @root ? nil : :start_anchor
    end

    def dir_or_start_anchor
      @root ? :any_dir : :dir_or_start_anchor
    end

    def anchored!
      @re[@start_index] = start_anchor unless @unanchorable
    end

    def anchored?
      @re[@start_index] == start_anchor
    end

    def never_anchored!
      @re[@start_index] = dir_or_start_anchor
      @unanchorable = true
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

    def process_star_end_after_slash # rubocop:disable Metrics/MethodLength
      if @s.star_end?
        append_part :many_non_dir
        emit_end
      elsif @s.two_star_end?
        break!
      elsif @s.star_slash_end?
        append_part :many_non_dir
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
          append_part :any_non_dir
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
        append_part :any_non_dir
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
          next if process_slash
          next if process_two_stars
          next append_part :any_non_dir if @s.star?
          next append_part :one_non_dir if @s.question_mark?
          next if process_character_class
          next if append_string(@s.literal)
          next if append_string(@s.significant_whitespace)

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

    def build_parent_matcher
      if anchored? || @root
        ancestors = @re.ancestors.each(&:compress)
        return Matchers::Blank if ancestors.empty?

        Matchers::MatchIfDir.build(
          Matchers::PathRegexp.build(RegexpBuilder.union(ancestors), negated?)
        )
      else
        Matchers::AllowAnyDir
      end
    end

    def build_child_matcher # rubocop:disable Metrics/MethodLength
      if @child_re.end_with?(:end_anchor)
        @child_re.end = :dir
      elsif @child_re.end_with?(:dir)
        if dir_only?
          @child_re.append_part :any_non_dir
          @child_re.append_part :dir
        end
      else
        @child_re.append_part :any_non_dir
        @child_re.append_part :dir
      end

      @child_re.compress
      Matchers::PathRegexp.build(@child_re, negated?)
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
      @re.compress

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
