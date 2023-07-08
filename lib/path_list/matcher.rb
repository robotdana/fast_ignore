# frozen_string_literal: true

class PathList
  # @api private
  # @abstract
  class Matcher
    Autoloader.autoload(self)

    class << self
      # @return [PathList::Matcher]
      alias_method :build, :new
    end

    # Does the candidate match this matcher
    # @param candidate [Candidate]
    # @return [:allow, :ignore, nil]
    #   :allow means explicitly allowed by this matcher,
    #   :ignore means explicitly ignored by this matcher,
    #   nil means this matcher has no opinion either way
    def match(_candidate)
      nil
    end

    # inspect
    alias_method :original_inspect, :inspect # leftovers:keep

    # @!method inspect
    #   @return [String] a string representation of self

    # @return [Numeric]
    #   an estimate for how costly this matcher is, used when sorting
    def weight
      1
    end

    # @return [:allow, :ignore, :mixed] which to group this matcher with
    def polarity
      :mixed
    end

    # @param other [PathList::Matcher]
    # @return [Boolean] whether this matcher can be merged with other
    alias_method :squashable_with?, :equal?

    # @param list [Array<PathList::Matcher>]
    #   list to merge, self will be the first item of this
    # @param preserve_order
    #   do we need to preserve the order when squashing this
    # @return [PathList::Matcher] a new matcher that is a union of the contributing matchers
    def squash(_list, _preserve_order)
      self
    end

    # @return [PathList::Matcher] this matcher as applicable to directories only
    alias_method :dir_matcher, :itself
    # @return [PathList::Matcher] this matcher as applicable to files only
    alias_method :file_matcher, :itself
  end
end
