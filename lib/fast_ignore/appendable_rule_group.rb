# frozen-string-literal: true

class FastIgnore
  class AppendableRuleGroup < ::FastIgnore::RuleGroup
    def initialize(root, allow)
      @root = root
      super([], allow)
    end

    def build
      @matchers = @patterns.flat_map { |x| x.build_matchers(allow: @allow) }.compact

      freeze
    end

    def append(new_pattern)
      return self if @patterns.include?(new_pattern)

      @patterns << new_pattern

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
        append(::FastIgnore::Patterns.new(*patterns, from_file: from_file, format: format, root: root))
      end

      self
    end

    def empty?
      false # if this gets removed then even if it's blank we can't add with GitignoreCollectingFileSystem
    end
  end
end
