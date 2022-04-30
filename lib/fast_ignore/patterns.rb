# frozen-string-literal: true

class FastIgnore
  class Patterns
    def initialize(*patterns, from_file: nil, format: :gitignore, root: nil)
      if from_file
        @root = root || ::File.dirname(from_file)
        @patterns = ::File.exist?(from_file) ? ::File.readlines(from_file) : []
      else
        @root = root || ::Dir.pwd
        @patterns = patterns.flatten.flat_map { |string| string.to_s.lines }
      end
      @root += '/' unless @root.end_with?('/')
      @expand_path_with = (@root if format == :expand_path)
    end

    def build_matchers(allow: false) # rubocop:disable Metrics/MethodLength
      matchers = @patterns.flat_map do |p|
        ::FastIgnore::Builders::ShebangOrGitignore.build(p, allow, expand_path_with: @expand_path_with)
      end

      return if matchers.empty?
      return [::FastIgnore::Matchers::WithinDir.new(matchers, @root)] unless allow

      [
        ::FastIgnore::Matchers::WithinDir.new(matchers, @root),
        ::FastIgnore::Matchers::WithinDir.new(
          ::FastIgnore::GitignoreIncludeRuleBuilder.new(@root).build_as_parent, '/'
        )
      ]
    end
  end
end
