# frozen_string_literal: true

class PathList
  class PatternParser
    # Match using this PathList merging of the gitignore format glob
    #
    # This is intended for merging values with glob expectations such as from ARGV cli arguments,
    # but with gitignore-style negation and better performance
    #
    # This format will be used by PathList for {PathList#only} and {PathList#ignore}
    # with `format: :glob_gitignore`
    # The `root:` in those methods is used to resolve relative paths
    #
    # When used with {PathList#only}, it will also allow all potentially containing directories (with a lower priority).
    #
    # Differences from standard gitignore patterns:
    # - Patterns beginning with `/` (or `!/`) are absolute. Not relative to the `root:` directory.
    # - Patterns beginning with `~` (or `!~`) are resolved relative to the home directory or.
    # - Patterns beginning with `./` or `../` (or `!./` or `!../`) are resolved relative to the `root:` directory
    # - Patterns beginning with `*` (or `!*`) will match any descendant of the `root:` directory
    # - Other patterns match children (not descendants) of the `root:` directory
    # - Patterns containing with `/../` will remove the previous path segment, (`/**/` counts as one path segment)
    # - Additionally, on windows:
    #   - either / or \ (slash or backslash) can be used as path separators.
    #   - therefore \ (backslash) isn't available to be used as an escape character
    #   - instead ` (grave accent) is used as an escape character anywhere a backslash would be used
    #   - patterns beginning with `c:/`, `d:\`, or `!c:/`, or etc are absolute.
    #   - a path beginning with / or \ is a shortcut for the current working directory's drive.
    # - there is no cross platform escape character.
    # @example
    #   PathList.only(ARGV, format: :glob_gitignore)
    #   PathList.only(
    #     './relative_to_current_dir',
    #     '/Users/dana/Projects/my_project/or_an_absolute_path',
    #     'relative_to_current_dir_not_just_any_descendant',
    #     '**/any_descendant',
    #     '*_spec.rb'
    #     '!we_can_also_negate',
    #     '!/all/of/these/patterns/',
    #     format: :glob_gitignore
    #   ).to_a
    #   PathList.only('./relative_to_root_dir', format: :glob_gitignore, root: './subdir')
    #   # on windows
    #   PathList.only('c:\root\path', 'relative\to\current\dir, format: :glob_gitignore)
    # @see https://git-scm.com/docs/gitignore#_pattern_format
    # @see ::PathList::PatternParser::Gitignore
    class GlobGitignore < Gitignore
      Autoloader.autoload(self)

      # @return [Boolean]
      def process_root
        root = @s.root_end
        dir_only! if root
        root ||= @s.root

        return false unless root

        @root = ::File.expand_path(root)
        emitted!
        true
      end

      # @return [Boolean]
      def process_home
        home = @s.home_slash_end
        dir_only! if home
        home ||= @s.home_slash_or_end

        return false unless home

        @root = ::File.expand_path(home)
        emitted!
        true
      rescue ::StandardError
        @s.unscan
        nil
      end

      # @return [true]
      def process_up_a_level
        @re.up_a_level
        emitted!
        true
      end

      # @return [Boolean]
      def end_with_dir?
        @re.end_with_dir?
      end

      # @return [void]
      def process_first_characters
        if process_root || process_home
          prepare_regexp_builder
          anchored!
          return
        end

        prepare_regexp_builder
        return @s.unscan if @s.star?

        anchored!
        return dir_only! && emitted! if @s.dot_slash_end?
        return emitted! if @s.dot_slash_or_end?
        return process_up_a_level && dir_only! if @s.dot_dot_slash_end?

        process_up_a_level if @s.dot_dot_slash_or_end?
      end

      # @return [void]
      def process_next_characters
        return dir_only! && emitted! if end_with_dir? && @s.dot_slash_end?
        return emitted! if end_with_dir? && @s.dot_slash_or_end?
        return process_up_a_level && dir_only! if end_with_dir? && @s.dot_dot_slash_end?
        return process_up_a_level if end_with_dir? && @s.dot_dot_slash_or_end?

        super
      end
    end
  end
end
