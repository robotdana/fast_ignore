# frozen_string_literal: true

class PathList
  class Matcher
    # @api private
    class PathRegexp < MatchRegexp
      Autoloader.autoload(self)

      # @param (see MatchRegexp.build)
      # @return (see MatchRegexp.build)
      def self.build(regexp_tokens, polarity)
        return Blank if regexp_tokens.all?(&:empty?)

        if CanonicalPath.case_insensitive?
          self::CaseInsensitive.new(build_regexp(regexp_tokens), polarity, regexp_tokens)
        else
          new(build_regexp(regexp_tokens), polarity, regexp_tokens)
        end
      end

      # @param (see Matcher#match)
      # @return (see Matcher#match)
      def match(candidate)
        @polarity if @regexp.match?(candidate.full_path)
      end

      private

      def calculate_weight
        # chaos guesses
        (@regexp.inspect.length / 4.0) + 2
      end
    end
  end
end
