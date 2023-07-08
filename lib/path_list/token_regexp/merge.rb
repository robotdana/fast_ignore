# frozen_string_literal: true

class PathList
  class TokenRegexp
    # @api private
    module Merge
      class << self
        # @param [Array<T>]
        # @return [Hash{T=>Hash{T => Hash{T =>...}, nil}, nil]
        def merge(arrays)
          tree_hash_proc = ->(h, k) { h[k] = Hash.new(&tree_hash_proc) }
          tree = Hash.new(&tree_hash_proc)

          arrays.each do |array|
            if array.length < 2
              tree[array.first] = nil
            else
              *path, last = array
              tree.dig(*path)&.merge!(last => nil)
            end
          end

          tree.default = nil
          tree
        end
      end
    end
  end
end
