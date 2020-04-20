# frozen_string_literal: true

# This is a backport of ruby 2.5's delete_prefix/delete_suffix methods
class FastIgnore
  module Backports
    module DeletePrefixSuffix
      refine ::String do
        def delete_prefix!(str)
          slice!(0..(str.length - 1)) if start_with?(str)
          self
        end

        def delete_suffix!(str)
          slice!(-str.length..-1) if end_with?(str)
          self
        end

        def delete_prefix(str)
          dup.delete_prefix!(str)
        end

        def delete_suffix(str) # leftovers:allowed
          dup.delete_suffix!(str)
        end
      end
    end
  end
end
