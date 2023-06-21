# frozen_string_literal: true

class PathList
  class GitignoreIncludeRuleBuilder < GitignoreRuleBuilder
    def initialize(rule, expand_path_with: nil)
      super

      @negated = true
    end

    def negated!
      unnegated!
    end

    def unmatchable_rule!
      throw :abort_build, Matchers::Invalid
    end

    def emit_end
      @re.append_part :end_anchor
      break!
    end

    def build_parent_matcher
      return Matchers::Blank unless negated?

      if anchored?
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
  end
end
