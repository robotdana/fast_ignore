# frozen_string_literal: true

# This is a backport of ruby 2.5's each_child method
class FastIgnore
  module Backports
    module DirEachChild
      refine ::Dir.singleton_class do
        def each_child(path, &block)
          Dir.entries(path).each do |entry|
            next if entry == '.' || entry == '..'

            block.call entry
          end
        end
      end
    end
  end
end
