# frozen_string_literal: true

class PathList
  module Matchers
    class WithinDir < Wrapper
      def self.build(dir, matcher)
        return matcher if matcher == Blank || dir == '/'

        new(dir, matcher)
      end

      def initialize(dir, matcher)
        @dir = dir
        @candidate_object = RelativeCandidate.allocate

        super(matcher)
      end

      def squashable_with?(other)
        other.instance_of?(self.class) && @dir == other.dir
      end

      def match(candidate)
        relative_candidate = candidate.relative_to(@dir, @candidate_object)

        return unless relative_candidate

        @matcher.match(relative_candidate)
      end

      def inspect
        "#{self.class}.new(\n  #{@dir.inspect},\n#{@matcher.inspect.gsub(/^/, '  ')}\n)"
      end

      def eql?(other)
        super(other, except: [:@candidate_object])
      end
      alias_method :==, :eql?

      protected

      attr_reader :dir

      private

      def new_with_matcher(matcher)
        self.class.build(@dir, matcher)
      end

      def calculate_weight
        # how much of this project is inside this directory...
        (super / 2.0) + 1
      end
    end
  end
end
