# frozen_string_literal: true

class FastIgnore
  class RuleSet
    def initialize(new_item, label: nil, walker: nil, from: nil)
      @array = [*from&.array, new_item]

      @appendable_groups = if label
        { **from&.appendable_groups, label => new_item }
      else
        from&.appendable_groups || {}
      end
      @walker = walker || from&.walker

      freeze
    end

    def allowed_recursive?(candidate)
      @array.all? { |r| r.allowed_recursive?(candidate) }
    end

    def allowed_unrecursive?(candidate)
      @array.all? { |r| r.allowed_unrecursive?(candidate) }
    end

    def append(label, pattern)
      @appendable_groups.fetch(label).append(pattern)
    end

    def append_until_root(label, *patterns, dir:, from_file: nil, format: :gitignore)
      @appendable_groups.fetch(label)
        .append_until_root(*patterns, from_file: from_file, format: format, dir: dir)
    end

    def query
      build unless @array.frozen?

      @walker || ::FastIgnore::Walkers::FileSystem
    end

    protected

    attr_reader :appendable_groups
    attr_reader :array
    attr_reader :walker

    private

    def build
      @array.each(&:build)
      @array.reject!(&:empty?)
      @array.sort_by!(&:weight)
      @array.freeze
    end
  end
end
