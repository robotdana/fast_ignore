# frozen_string_literal: true

class PathList
  class RegexpBuilder
    module Merge
      class << self
        def merge(hashes)
          first_hash, *other_hashes = hashes
          return first_hash if other_hashes.empty?

          first_hash.merge(*other_hashes) do |_, left, right|
            if left && right
              merge_2(left, right)
            elsif left || right
              merge_2(left || { nil => nil }, right || { nil => nil })
            end
          end
        end

        def merge_2(hash, other_hash)
          hash.merge(other_hash) do |_, left, right|
            if left && right
              merge_2(left, right)
            elsif left || right
              merge_2(left || { nil => nil }, right || { nil => nil })
            end
          end
        end

        def merge_2!(hash, other_hash)
          hash.merge!(other_hash) do |_, left, right|
            if left && right
              merge_2(left, right)
            elsif left || right
              merge_2(left || { nil => nil }, right || { nil => nil })
            end
          end
        end
      end
    end
  end
end
