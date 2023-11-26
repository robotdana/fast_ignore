# frozen_string_literal: true

class PathList
  class PatternParser
    # Match using the format used in gitignore files by git, plus many others,
    # such as `.dockerignore` or `.eslintignore`
    #
    # This format will be used by PathList for {PathList#gitignore},
    # and for {PathList#only} and {PathList#ignore} with `format: :gitignore`
    # The `root:` in those methods is used as the file location for patterns that start with or include `/`
    #
    # When used with `only`, it will also allow all potentially containing directories (with a lower priority).
    #
    # @see https://git-scm.com/docs/gitignore#_pattern_format
    class Gitignore
      Autoloader.autoload(self)

      SCANNER = RuleScanner

      # @api private
      # @param pattern [String]
      # @param polarity [:ignore, :allow]
      # @param root [String]
      def initialize(pattern, polarity, root)
        @s = self.class::SCANNER.new(pattern)
        @default_polarity = polarity
        @rule_polarity = polarity
        @root = root

        @dir_only ||= false
        @emitted = false
        @return = nil
        @anchored ||= false
      end

      # @api private
      # @return [PathList::Matcher]
      def matcher
        process_rule

        @return || build_matcher
      end

      # @api private
      # @return [PathList::Matcher]
      def implicit_matcher
        process_rule
        return Matcher::Blank if negated?

        @return || build_implicit_matcher
      end

      private

      def prepare_regexp_builder
        @re = if @root.end_with?('/')
          TokenRegexp::Path.new_from_path(@root, tail: [:any_dir])
        else
          TokenRegexp::Path.new_from_path(@root, tail: [:dir, :any_dir])
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
        @re.remove_trailing_dir
        append_part :end_anchor
        break!
      end

      def process_escape
        return unless @s.escape?

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
          next if process_escape
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

        append_string(start)

        finish = @s.character_class_range_end

        return true unless start < finish

        append_part :character_class_dash
        append_string(finish)
      end

      def process_end
        blank! if nothing_emitted?

        emit_end
      end

      def process_rule
        return if defined?(@rule_processed)

        @rule_processed = true

        catch :abort_build do
          blank! if @s.hash?
          negated! if @s.exclamation_mark?
          process_first_characters

          catch :break do
            loop do
              process_next_characters
            end
          end
        end
      end

      def process_first_characters
        prepare_regexp_builder
        anchored! if !@anchored && @s.slash?
      end

      def process_next_characters
        return if process_escape
        return unmatchable_rule! if @s.star_star_slash_slash?
        return append_part(:any) && dir_only! if @s.star_star_slash_end?
        return append_part(:any_dir) && anchored! if @s.star_star_slash?
        return unmatchable_rule! if @s.slash_slash?
        return append_part(:dir) && append_part(:any) && anchored! if @s.slash_star_star_end?
        return append_part(:any_non_dir) if @s.star?
        return dir_only! if @s.slash_end?
        return append_part(:dir) && anchored! if @s.slash?
        return append_part(:one_non_dir) if @s.question_mark?
        return if process_character_class
        return if append_string(@s.literal)
        return if append_string(@s.significant_whitespace)

        process_end
      end

      def build_matcher
        @main_re ||= @re.dup.compress

        matcher = if @main_re.empty?
          @rule_polarity == :ignore ? Matcher::Ignore : Matcher::Allow
        elsif @re.exact_path?
          Matcher::ExactString.build([@main_re.to_s], @rule_polarity)
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
