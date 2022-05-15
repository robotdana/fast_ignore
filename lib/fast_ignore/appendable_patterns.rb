# frozen_string_literal: true

class FastIgnore
  class AppendablePatterns
    def initialize(*patterns, from_file: nil, format: nil, root: nil, allow: false)
      pattern = ::FastIgnore::Patterns.new(patterns, from_file: from_file, format: format, root: root, allow: allow)

      @patterns = [pattern]
      @root = pattern.root
      @allow = allow
    end

    def build
      @matchers = @patterns.flat_map { |x| x.build_matchers(allow: @allow) }.compact
      freeze

      FastIgnore::Matchers::RuleGroup.new(@matchers, @allow, appendable: true)
    end

    def append(*patterns, from_file: nil, format: nil, root: @root)
      new_pattern = ::FastIgnore::Patterns.new(
        *patterns, from_file: from_file, format: format, root: root, allow: @allow
      )

      return self if @patterns.include?(new_pattern)

      @patterns << new_pattern # for comparison

      return self unless defined?(@matchers)

      new_matchers = new_pattern.build_matchers(allow: @allow)
      return self if !new_matchers || new_matchers.empty?

      @matchers.concat(new_matchers)

      self
    end

    def append_until_root(*patterns, dir:, from_file: nil, format: :gitignore)
      dirs = [dir]

      while dir != @root
        dir = "#{::File.dirname(dir)}/"
        dirs << dir
      end

      dirs.reverse_each do |root|
        append(*patterns, from_file: from_file, format: format, root: root)
      end

      self
    end
  end
end
