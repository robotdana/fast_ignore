# frozen-string-literal: true

class FastIgnore
  class AppendableRuleGroup < ::FastIgnore::RuleGroup
    def initialize(allow)
      super([], allow)
    end

    def build
      @matchers = @patterns.flat_map { |x| x.build_matchers(allow: @allow) }.compact

      freeze
    end

    def append(new_pattern)
      return if @patterns.include?(new_pattern)

      @patterns << new_pattern

      return unless defined?(@matchers)

      new_matchers = new_pattern.build_matchers(allow: @allow)
      return if !new_matchers || new_matchers.empty?

      @matchers.concat(new_matchers)
    end

    def empty?
      false # if this gets removed then even if it's blank we can't add with GitignoreCollectingFileSystem
    end
  end
end
