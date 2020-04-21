# frozen_string_literal: true

# This is a backport of ruby 2.5's delete_prefix/delete_suffix methods
class FastIgnore
  module Backports
    module DeletePrefixSuffix
      refine ::String do
        # delete_prefix!(prefix) -> self or nil
        # Deletes leading prefix from str, returning nil if no change was made.
        #
        #   "hello".delete_prefix!("hel") #=> "lo"
        #   "hello".delete_prefix!("llo") #=> nil
        def delete_prefix!(str)
          return unless start_with?(str)

          slice!(0..(str.length - 1))
          self
        end

        # delete_suffix!(suffix) -> self or nil
        # Deletes trailing suffix from str, returning nil if no change was made.
        #
        #   "hello".delete_suffix!("llo") #=> "he"
        #   "hello".delete_suffix!("hel") #=> nil
        def delete_suffix!(str)
          return unless end_with?(str)

          slice!(-str.length..-1)
          self
        end

        # delete_prefix(prefix) -> new_str click to toggle source
        # Returns a copy of str with leading prefix deleted.
        #
        #   "hello".delete_prefix("hel") #=> "lo"
        #   "hello".delete_prefix("llo") #=> "hello"
        def delete_prefix(str)
          s = dup
          s.delete_prefix!(str)
          s
        end

        # delete_suffix(suffix) -> new_str
        # Returns a copy of str with trailing suffix deleted.
        #
        #   "hello".delete_suffix("llo") #=> "he"
        #   "hello".delete_suffix("hel") #=> "hello"
        def delete_suffix(str) # leftovers:allowed
          s = dup
          s.delete_suffix!(str)
          s
        end
      end
    end
  end
end
