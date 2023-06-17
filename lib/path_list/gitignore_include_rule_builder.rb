# frozen_string_literal: true

class PathList
  class GitignoreIncludeRuleBuilder < GitignoreRuleBuilder
    def initialize(rule, expand_path_with: nil)
      super

      @negation = true
    end

    def negated!
      @negation = false
    end

    def unmatchable_rule!
      throw :abort_build, Matchers::Unmatchable
    end

    def emit_end
      @child_re = @re.dup
      super
    end

    def build_parent_dir_rules # rubocop:disable Metrics/MethodLength
      return Matchers::Null unless @negation

      if @anchored
        parent_pattern = @s.string.dup
        if parent_pattern.sub!(%r{/[^/]+/?\s*\z}, '/')
          GitignoreIncludeRuleBuilder.new(parent_pattern).build_as_parent
        else
          Matchers::Null
        end
      else
        Matchers::AllowAnyDir
      end
    end

    def build_child_file_rule
      if @child_re.end_with?('/')
        @child_re.append_many_non_dir.append_dir if @dir_only
      else
        @child_re.append_dir
      end

      @child_re.prepend(prefix)

      Matchers::PathRegexp.build(@child_re.to_regexp, @anchored, @negation)
    end

    def build_as_parent
      anchored!
      dir_only!

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

        @anchored = false if @anchored == :never

        build_implicit_rule
      end
    end

    def build_implicit_rule(child_file_rule: true, parent: false) # rubocop:disable Metrics/MethodLength
      @child_re ||= @re.dup # in case emit_end wasn't called

      Matchers::Any.build([
        (
          if parent && @anchored && @dir_only && @negation
            @re.prepend(prefix)

            Matchers::MatchIfDir.build(
              Matchers::PathRegexp.build(@re.to_regexp, true, true)
            )
          elsif parent
            build_rule
          end
        ),
        *build_parent_dir_rules,
        (build_child_file_rule if child_file_rule && @negation)
      ].compact)
    end
  end
end
