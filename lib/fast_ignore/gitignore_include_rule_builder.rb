# frozen_string_literal: true

class FastIgnore
  class GitignoreIncludeRuleBuilder < GitignoreRuleBuilder
    def initialize(rule, expand_path_with: nil)
      super

      @negation = true
    end

    def negated!
      @negation = false
    end

    def unmatchable_rule!
      throw :abort_build, ::FastIgnore::Matchers::Unmatchable
    end

    def emit_end
      if @dir_only
        @child_re = @re.dup
        @re.append_end_anchor
      else
        @re.append_dir_or_end_anchor
      end

      break!
    end

    def build_parent_dir_rules
      return unless @negation

      if @anchored
        parent_pattern = @s.string.dup
        if parent_pattern.sub!(%r{/[^/]+/?\s*\z}, '/')
          ::FastIgnore::GitignoreIncludeRuleBuilder.new(parent_pattern).build_as_parent
        end
      else
        [::FastIgnore::Matchers::AllowAnyDir]
      end
    end

    def build_child_file_rule
      if @child_re.end_with?('/')
        @child_re.append_many_non_dir.append_dir if @dir_only
      else
        @child_re.append_dir
      end

      @child_re.prepend(prefix)

      ::FastIgnore::Matchers::PathRegexp.new(@child_re.to_regexp, @anchored, false, @negation)
    end

    def build_as_parent
      anchored!
      dir_only!

      catch :abort_build do
        process_rule
        build_rule(child_file_rule: false)
      end
    end

    def build_rule(child_file_rule: true)
      @child_re ||= @re.dup # in case emit_end wasn't called

      [super(), *build_parent_dir_rules, (build_child_file_rule if child_file_rule)].compact
    end
  end
end
