# frozen-string-literal: true

class FastIgnore
  def self.Patterns(*patterns, from_file: nil, format: :gitignore, root: nil)
    ::FastIgnore::Patterns.new(*patterns, from_file: from_file, format: format, root: root)
  end

  class Patterns
    def initialize(*patterns, from_file: nil, format: :gitignore, root: nil)
      raise ArgumentError, "from_file: can't be used with patterns arguments" unless patterns.empty? || !from_file

      @format = format
      if from_file
        @root = root || ::File.dirname(from_file)
        @patterns = ::File.exist?(from_file) ? ::File.readlines(from_file) : []
      else
        @root = root || ::Dir.pwd
        @patterns = patterns.flatten.flat_map { |string| string.to_s.lines }
      end
      @root += '/' unless @root.end_with?('/')
    end

    def build_matchers(include: false)
      matchers = @patterns.flat_map { |p| ::FastIgnore::RuleBuilder.build(p, include, @format, @root) }

      return if matchers.empty?
      return [::FastIgnore::Matchers::WithinDir.new(matchers, @root)] unless include

      [
        ::FastIgnore::Matchers::WithinDir.new(matchers, @root),
        ::FastIgnore::Matchers::WithinDir.new(
          ::FastIgnore::GitignoreIncludeRuleBuilder.new(@root).build_as_parent, '/'
        )
      ]
    end
  end
end
