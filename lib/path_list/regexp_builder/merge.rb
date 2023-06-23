# frozen_string_literal: true

class PathList
  class RegexpBuilder
    module Merge
      class << self
        def merge(hashes)
          first_hash, *other_hashes = hashes
          return first_hash if other_hashes.empty?

          first_hash.merge(*other_hashes) do |_, a, b|
            if a.is_a?(Hash) && b.is_a?(Hash)
              merge_2(a, b)
            elsif !a.nil? || !b.nil?
              a = { nil => nil } if a.nil?
              b = { nil => nil } if b.nil?

              merge_2(a, b)
            end
          end
        end

        def merge_2(hash, other_hash)
          hash.merge(other_hash) do |_, a, b|
            if a.is_a?(Hash) && b.is_a?(Hash)
              merge_2(a, b)
            elsif !a.nil? || !b.nil?
              a = { nil => nil } if a.nil?
              b = { nil => nil } if b.nil?

              merge_2(a, b)
            end
          end
        end

        def merge_2!(hash, other_hash)
          hash.merge!(other_hash) do |_, a, b|
            if a.is_a?(Hash) && b.is_a?(Hash)
              merge_2(a, b)
            elsif !a.nil? || !b.nil?
              a = { nil => nil } if a.nil?
              b = { nil => nil } if b.nil?

              merge_2(a, b)
            end
          end
        rescue
          require 'pry'
          binding.pry
        end
      end
    end
  end
end
