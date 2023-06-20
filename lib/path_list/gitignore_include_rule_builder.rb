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
      @rule.append :end_anchor_for_include
      break!
    end

    def build_parent_dir_rules
      return Matchers::Blank unless @rule.negated?

      if @rule.anchored?
        @rule.dup.build_parents
      else
        Matchers::AllowAnyDir
      end
    end

    def build_child_file_rule # rubocop:disable Metrics/MethodLength
      if @child_rule.end_with?(:end_anchor_for_include)
        @child_rule.remove_end_anchor_for_include
        @child_rule.append :dir
      elsif @child_rule.end_with?(:dir)
        if @child_rule.dir_only?
          @child_rule.append :any_non_dir
          @child_rule.append :dir
        end
      else
        @child_rule.append :any_non_dir
        @child_rule.append :dir
      end

      @child_rule.compress
      @child_rule.build_path_matcher
    end

    def build_implicit
      catch :abort_build do
        blank! if @s.hash?

        negated! if @s.exclamation_mark?
        process_rule

        build_implicit_rule
      end
    end

    def build_implicit_rule
      @child_rule ||= @rule.dup # in case emit_end wasn't called
      @rule.compress

      if @rule.negated?
        Matchers::Any.build([build_parent_dir_rules, build_child_file_rule])
      else
        build_parent_dir_rules
      end
    end
  end
end
