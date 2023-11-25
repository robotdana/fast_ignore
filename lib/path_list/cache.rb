# frozen_string_literal: true

class PathList
  # @api private
  class Cache
    Key = Struct.new(
      :patterns,
      :patterns_from_file,
      :gitignore_global,
      :root,
      :pwd,
      :polarity,
      :parser,
      :default,
      keyword_init: true
    )

    # @api private
    class Key
      def initialize( # rubocop:disable Metrics/ParameterLists
        patterns: nil,
        patterns_from_file: nil,
        gitignore_global: nil,
        root: nil,
        pwd: Dir.pwd,
        polarity: :ignore,
        parser: PatternParser::Gitignore,
        default: nil
      )
        super
        freeze
      end

      freeze
    end

    @cache = {}
    class << self
      # @yield
      # @return [Object] Whatever the block returns
      def cache(**args)
        @cache[Key.new(**args)] ||= yield
      end

      # @return [void]
      def clear
        @cache.clear
      end
    end
  end
end
