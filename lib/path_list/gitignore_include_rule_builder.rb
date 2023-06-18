# frozen_string_literal: true

class PathList
  class GitignoreIncludeRuleBuilder < GitignoreRuleBuilder
    def initialize(rule, expand_path_with: nil)
      super

      @rule.negated!
    end

    def negated!
      @rule.unnegated!
    end

    def unmatchable_rule!
      throw :abort_build, Matchers::Invalid
    end

    def emit_end
      @child_rule = @rule.dup
      super
    end

    def build_parent_dir_rules # rubocop:disable Metrics/MethodLength
      return Matchers::Blank unless @rule.negated?

      # TODO: unfuck this:
      if @rule.anchored?
        parent_pattern = @s.string.dup
        if parent_pattern.sub!(%r{/[^/]+/?\s*\z}, '/')
          GitignoreIncludeRuleBuilder.new(parent_pattern).build_as_parent
        else
          Matchers::Blank
        end
      else
        Matchers::AllowAnyDir
      end
    end

    def build_child_file_rule
      if @child_rule.end_with?(:dir)
        if @rule.dir_only?
          @child_rule.append_many_non_dir
          @child_rule.append_dir
        end
      else
        @child_rule.append_dir
      end

      Matchers::PathRegexp.build(@child_rule.to_regexp, @child_rule.anchored?, @child_rule.negated?)
    end

    def build_as_parent
      @rule.anchored!
      @rule.dir_only!

      catch :abort_build do
        process_rule
        build_implicit_rule(child_file_rule: false, parent: true)
      end
    end

    def build_implicit
      catch :abort_build do
        blank! if @s.hash?

        negated! if @s.exclamation_mark?
        process_rule

        build_implicit_rule
      end
    end

    def build_implicit_rule(child_file_rule: true, parent: false) # rubocop:disable Metrics/MethodLength
      @child_rule ||= @rule.dup # in case emit_end wasn't called

      Matchers::Any.build([
        (
          if parent && @rule.anchored? && @rule.dir_only? && @rule.negated?
            Matchers::MatchIfDir.build(
              Matchers::PathRegexp.build(@rule.to_regexp, true, true)
            )
          elsif parent
            build_rule
          end
        ),
        *build_parent_dir_rules,
        (build_child_file_rule if child_file_rule && @rule.negated?)
      ].compact)
    end
  end
end
