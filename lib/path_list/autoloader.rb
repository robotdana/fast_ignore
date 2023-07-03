# frozen_string_literal: true

class PathList
  module Autoloader
    # zero dependency zeitwerk

    class << self
      def autoload(klass)
        ::Dir[glob_children(klass)].each_entry do |path|
          klass.autoload(class_from_path(path), path)
        end
      end

      private

      def class_from_path(path)
        name = ::File.basename(path).delete_suffix('.rb')

        if name == 'version'
          name.upcase
        else
          name.gsub(/(?:^|_)(\w)/, &:upcase).delete('_')
        end
      end

      def dir_path_from_class(klass)
        klass.name.gsub('::', '/')
          .gsub(/(?<=[a-z])([A-Z])/, '_\1').downcase
      end

      def glob_children(klass)
        "#{root}/#{dir_path_from_class(klass)}/*.rb"
      end

      def root
        ::File.dirname(__dir__)
      end
    end
  end
end
