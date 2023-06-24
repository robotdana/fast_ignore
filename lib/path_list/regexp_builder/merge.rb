# frozen_string_literal: true

class PathList
  class RegexpBuilder
    module Merge
      class << self
        def merge(hashes) # rubocop:disable Metrics/MethodLength
          first_hash, *other_hashes = hashes
          return first_hash if other_hashes.empty?

          first_hash.merge(*other_hashes) do |_, left, right|
            if left.is_a?(Hash) && right.is_a?(Hash)
              merge_2(left, right)
            elsif !left.nil? || !right.nil?
              left = { nil => nil } if left.nil?
              right = { nil => nil } if right.nil?

              merge_2(left, right)
            end
          end
        end

        def merge_2(hash, other_hash)
          hash.merge(other_hash) do |_, left, right|
            if left.is_a?(Hash) && right.is_a?(Hash)
              merge_2(left, right)
            elsif !left.nil? || !right.nil?
              left = { nil => nil } if left.nil?
              right = { nil => nil } if right.nil?

              merge_2(left, right)
            end
          end
        end

        def merge_2!(hash, other_hash)
          hash.merge!(other_hash) do |_, left, right|
            if left.is_a?(Hash) && right.is_a?(Hash)
              merge_2(left, right)
            elsif !left.nil? || !right.nil?
              left = { nil => nil } if left.nil?
              right = { nil => nil } if right.nil?

              merge_2(left, right)
            end
          end
        end
      end
    end
  end
end
