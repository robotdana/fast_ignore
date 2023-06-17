# frozen_string_literal: true

class PathList
  module Matchers
    class Appendable < Wrapper
      class << self
        alias_method :build, :new
      end

      def initialize(label, default_matcher, implicit_matcher, explicit_matcher, pattern)
        @label = label
        @default_matcher = default_matcher
        @implicit_matcher = implicit_matcher
        @explicit_matcher = explicit_matcher
        @loaded = [pattern]

        build_matcher
      end

      # TODO: maybe w the same label?
      def squashable_with?(_)
        false
      end

      def match(candidate)
        @matcher.match(candidate)
      end

      def inspect
        super("@label=#{@label.inspect}")
      end

      def append(pattern)
        pattern.allow = append_with_allow
        return unless pattern.content?
        return if @loaded.include?(pattern)

        new_implicit, new_explicit = pattern.build_matchers

        @implicit_matcher = Any.build([@implicit_matcher, new_implicit])
        @explicit_matcher = LastMatch.build([@explicit_matcher, new_explicit])
        @loaded << pattern

        build_matcher
      end

      private

      def append_with_allow
        @default_matcher == Ignore
      end

      def build_matcher
        @matcher = if @implicit_matcher == Null && @explicit_matcher == Null
          Allow
        else
          LastMatch.build([@default_matcher, @implicit_matcher, @explicit_matcher])
        end
      end
    end
  end
end
