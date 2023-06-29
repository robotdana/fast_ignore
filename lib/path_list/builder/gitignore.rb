# frozen_string_literal: true

class PathList
  class Builder
    class Gitignore < Builder # rubocop:disable Metrics/ClassLength
      def initialize(rule, polarity, root) # rubocop:disable Lint/MissingSuper
        @s = GitignoreRuleScanner.new(rule)
        @default_polarity = polarity
        @rule_polarity = polarity
        @root = root

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
        @return ||= Matchers::Blank
        throw :abort_build
      end

      def unmatchable_rule!
        @return ||= (@default_polarity == :allow ? Matchers::Invalid : Matchers::Blank)
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

      def process_character_class # rubocop:disable Metrics/MethodLength
        return unless @s.character_class_start?

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

      def process_rule # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
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
        matcher = if @re.exact_string?
          Matchers::ExactString.build([@re.to_s.downcase], @rule_polarity)
        else
          Matchers::PathRegexp.build(@re, @rule_polarity)
        end
        matcher = Matchers::MatchIfDir.build(matcher) if dir_only?
        matcher
      end

      def build
        process_rule

        @return || build_matcher
      end

      def build_parent_matcher
        if anchored? || @root
          ancestors = @re.ancestors
          return Matchers::Blank if ancestors.empty?

          Matchers::MatchIfDir.build(Matchers::PathRegexp.build(ancestors, :allow))
        else
          Matchers::AllowAnyDir
        end
      end

      def build_child_matcher
        @child_re = @re.dup
        @child_re.replace_tail(:dir)
        Matchers::PathRegexp.build(@child_re, :allow)
      end

      def build_implicit
        process_rule
        return Matchers::Blank if negated?

        @return || build_implicit_matcher
      end

      def build_implicit_matcher
        Matchers::Any.build([
          build_parent_matcher,
          build_child_matcher
        ])
      end
    end
  end
end
