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
    # - Patterns beginning with `~` (or `!~`) are resolved relative to the `$HOME` or `~user` directory
    # - Patterns beginning with `./` or `../` (or `!./` or `!../`) are resolved relative to the `root:` directory
    # - Patterns containing with `/../` are resolved relative to the `root:` directory
    # - Patterns beginning with `*` (or `!*`) will match any descendant of the `root:` directory
    # - Other patterns match children (not descendants) of the `root:` directory
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
    # @see https://git-scm.com/docs/gitignore#_pattern_format
    # @see ::PathList::PatternParser::Gitignore
    class GlobGitignore < Gitignore
      # @api private
      # @param pattern [String]
      # @param polarity [:ignore, :allow]
      # @param root [String]
      def initialize(pattern, polarity, root)
        pattern = +'' if pattern.start_with?('#')
        negated_sigil = '!' if pattern.delete_prefix!('!')
        if pattern.start_with?('*')
          pattern = "#{negated_sigil}#{pattern}"
        elsif pattern.match?(%r{(?:\A[~/]|\A\.{1,2}/|(?:[^\\]|\A)(?:\\{2})*/\.\./)})
          dir_only! if pattern.match?(%r{/\s*\z}) # expand_path will remove it
          pattern = "#{negated_sigil}#{PathExpander.expand_path(pattern, root)}"
          root = '/'
        else
          pattern = "#{negated_sigil}/#{pattern}"
        end

        super(pattern, polarity, root)
      end
    end
  end
end
