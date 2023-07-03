# frozen_string_literal: true

class PathList
  class Builder
    class Gitignore < Builder
      def initialize(rule, polarity, root) # rubocop:disable Lint/MissingSuper
        @s = GitignoreRuleScanner.new(rule)
        @default_polarity = polarity
        @rule_polarity = polarity
        @root = root

        @dir_only = false
        @emitted = false
      end

      def build
        process_rule

        @return || build_matcher
      end

      def build_implicit
        process_rule
        return Matcher::Blank if negated?

        @return || build_implicit_matcher
      end

      private

      def prepare_regexp_builder
        @re = if @root && @root != '/'
          PathRegexp.new_from_path(@root, [:dir, :any_dir])
        else
          PathRegexp.new([:start_anchor, :dir, :any_dir])
        end

        @start_any_dir_position = @re.length - 1
      end

      def break!
        throw :break
      end

      def blank!
        @return ||= Matcher::Blank
        throw :abort_build
      end

      def unmatchable_rule!
        @return ||= (@default_polarity == :allow ? Matcher::Invalid : Matcher::Blank)
        throw :abort_build
      end

      def negated!
        @rule_polarity = @default_polarity == :allow ? :ignore : :allow
      end

      def negated?
        @rule_polarity != @default_polarity
      end

      def dir_only!
        @dir_only = true
      end

      def dir_only?
        @dir_only
      end

      def anchored!
        @anchored ||= begin
          @re.delete_at(@start_any_dir_position)
          true
        end
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

      def emit_end
        append_part :end_anchor
        break!
      end

      def process_backslash
        return unless @s.backslash?

        if @re.append_string(@s.next_character)
          emitted!
        else
          unmatchable_rule!
        end
      end

      def process_character_class
        return unless @s.character_class_start?

        outer = @re
        @re = TokenRegexp.new
        append_part :character_class_non_slash_open
        append_part :character_class_negation if @s.character_class_negation?
        unmatchable_rule! if @s.character_class_end?

        until @s.character_class_end?
          next if process_character_class_range
          next if process_backslash
          next if append_string(@s.character_class_literal)

          unmatchable_rule!
        end

        append_part :character_class_close
        character_class = TokenRegexp::Build.build_character_class(@re.parts)
        @re = outer
        append_part character_class
      end

      def process_character_class_range
        start = @s.character_class_range_start
        return unless start

        start = start.delete_prefix('\\')

        append_string(start)

        finish = @s.character_class_range_end.delete_prefix('\\')

        return true unless start < finish

        append_part :character_class_dash
        append_string(finish)
      end

      def process_end
        blank! if nothing_emitted?

        emit_end
      end

      def process_rule
        return if @rule_processed

        @rule_processed = true

        catch :abort_build do
          blank! if @s.hash?
          negated! if @s.exclamation_mark?
          prepare_regexp_builder
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
      end

      def build_matcher
        @main_re ||= @re.dup.compress

        matcher = if @main_re.empty?
          @rule_polarity == :ignore ? Matcher::Ignore : Matcher::Allow
        elsif @re.exact_path?
          Matcher::ExactString.build([@main_re.to_s.downcase], @rule_polarity)
        else
          Matcher::PathRegexp.build([@main_re.parts], @rule_polarity)
        end

        matcher = Matcher::MatchIfDir.build(matcher) if dir_only?
        matcher
      end

      def build_parent_matcher
        ancestors = @re.ancestors
        return Matcher::AllowAnyDir if ancestors.any?(&:empty?)

        exact, regexp = ancestors.partition(&:exact_path?)
        exact = Matcher::ExactString.build(exact.map(&:to_s), :allow)
        regexp = Matcher::PathRegexp.build(regexp.map(&:parts), :allow)

        Matcher::MatchIfDir.build(Matcher::Any.build([exact, regexp]))
      end

      def build_child_matcher
        @child_re = @re.dup
        @child_re.replace_end(:dir)
        child = @child_re.compress.parts
        return Matcher::Allow if child.empty?

        Matcher::PathRegexp.build([child], :allow)
      end

      def build_implicit_matcher
        Matcher::Any.build([
          build_parent_matcher,
          build_child_matcher
        ])
      end
    end
  end
end
