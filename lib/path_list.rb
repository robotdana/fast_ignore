# frozen_string_literal: true

# Build a `PathList` by chaining {#gitignore} {#only}, {#ignore},
# and combining these chains with {#union}, or {#intersection}
#
# - Yield each of the files not ignored by your PathList with {#each} or any other enumerable methods.
# - Test if a file path would be yielded by this PathList with {#include?}.
# - Test if a file or directory path would hypothetically be matchable by your PathList with {#match?}
#
# **Note:** If you want use the same PathList match rules more than once,
# save the pathlist to a variable to avoid having to read and parse the patterns over and over again
#
# @example
#   PathList.gitignore.each { |file| puts "#{file} is not ignored by git" }
#   PathList.gitignore.filter_map { |file| ::File.read(file) if ::File.readable?(file) }
#   PathList.only('*.rb', '!config/').each { |file| puts "#{file} is a ruby file not in the config directory" }
#   PathList.ignore(patterns_from_file: '.dockerignore').each { |file| puts "#{file} would be copied with COPY" }
#   PathList.intersection(PathList.gitignore, PathList.union(PathList.only('*.rb'), PathList.only('*.py')))
#
#   PathList.gitignore.include?("is/this/file/gitignored")
#   PathList.gitignore.match?("is/this")
#   PathList.gitignore.match?("is/this/hypothetical/directory", directory: true)
#
class PathList
  class Error < StandardError; end

  require_relative 'path_list/autoloader'
  Autoloader.autoload(self)

  include ::Enumerable

  def initialize
    @matcher = Matcher::Allow
    @dir_matcher = nil
    @file_matcher = nil
  end

  # @!group Gitignore methods

  # Return a new PathList that filters files using .gitignore files.
  #
  # This matcher aims for fidelity with `git ls-files`,
  # reading the configured core.excludesFile and .gitignore files in subdirectories
  #
  # @param root [String, Pathname, #to_s, nil]
  #   The git repo root. When nil, PathList will search up from the current directory like git does for a directory
  #   containing `.git/`. If it doesn't find anything, it will default to the current directory.
  # @param config [Boolean]
  #   Whether to load the configured `core.excludesFile`.
  #   When this is false this will only load patterns in `.gitignore` files in the `root:` directory and its children,
  #   and the `.git/info/exclude` file in the `root:` directory. When true it will also load config files in all the
  #   locations that git would also look, to find the core.excludesFile.
  # @return [PathList]
  #   a new PathList
  # @example
  #   PathList.gitignore.only('*.rb')
  #   path_list = PathList.only('*.rb'); path_list.gitignore!
  #   PathList.only('*.rb').gitignore(root: Dir.pwd) # don't look for a .git directory
  #   PathList.only('*.rb').gitignore(root: '../../') # the project root is two directories up
  #   PathList.only('*.rb').gitignore(config: false) # don't look for a configured core.excludesFile
  # @see #gitignore
  # @see #gitignore!
  # @see https://git-scm.com/docs/gitignore#_pattern_format
  def self.gitignore(root: nil, config: true)
    new.gitignore!(root: root, config: config)
  end

  # Return a new PathList that filters files using .gitignore files.
  #
  # This matcher aims for fidelity with `git ls-files`,
  # reading the configured core.excludesFile and .gitignore files in subdirectories
  #
  # @param root [String, Pathname, #to_s, nil]
  #   The git repo root. When nil, PathList will search up from the current directory like git does for a directory
  #   containing `.git/`. If it doesn't find anything, it will default to the current directory.
  # @param config [Boolean]
  #   Whether to load the configured `core.excludesFile`.
  #   When this is false this will only load patterns in `.gitignore` files in the `root:` directory and its children,
  #   and the `.git/info/exclude` file in the `root:` directory. When true it will also load config files in all the
  #   locations that git would also look, to find the core.excludesFile.
  # @return [PathList]
  #   a new PathList
  # @example
  #   PathList.gitignore.only('*.rb')
  #   path_list = PathList.only('*.rb'); path_list.gitignore!
  #   PathList.only('*.rb').gitignore(root: Dir.pwd) # don't look for a .git directory
  #   PathList.only('*.rb').gitignore(root: '../../') # the project root is two directories up
  #   PathList.only('*.rb').gitignore(config: false) # don't look for a configured core.excludesFile
  # @see .gitignore
  # @see #gitignore!
  # @see https://git-scm.com/docs/gitignore#_pattern_format
  def gitignore(root: nil, config: true)
    dup.gitignore!(root: root, config: config)
  end

  # Update self to filter files using .gitignore files.
  #
  # This matcher aims for fidelity with `git ls-files`,
  # reading the configured core.excludesFile and .gitignore files in subdirectories
  #
  # @param root [String, Pathname, #to_s, nil]
  #   The git repo root. When nil, PathList will search up from the current directory like git does for a directory
  #   containing `.git/`. If it doesn't find anything, it will default to the current directory.
  # @param config [Boolean]
  #   Whether to load the configured `core.excludesFile`.
  #   When this is false this will only load patterns in `.gitignore` files in the `root:` directory and its children,
  #   and the `.git/info/exclude` file in the `root:` directory. When true it will also load config files in all the
  #   locations that git would also look, to find the core.excludesFile.
  # @return [self]
  # @example
  #   PathList.gitignore.only('*.rb')
  #   path_list = PathList.only('*.rb'); path_list.gitignore!
  #   PathList.only('*.rb').gitignore(root: Dir.pwd) # don't look for a .git directory
  #   PathList.only('*.rb').gitignore(root: '../../') # the project root is two directories up
  #   PathList.only('*.rb').gitignore(config: false) # don't look for a configured core.excludesFile
  # @see .gitignore
  # @see #gitignore
  # @see https://git-scm.com/docs/gitignore#_pattern_format
  def gitignore!(root: nil, config: true)
    and_matcher(Gitignore.build(root: root, config: config))
  end

  # @!group Ignore methods

  # Return a new PathList that filters out files using the given patterns.
  #
  # @overload ignore(*patterns, format: :gitignore, root: nil)
  #   @param patterns [Array<String>]
  #     The list of patterns. Within an array, or as a line-separated string.
  #     The individual pattern format depends on the `format:` param
  #   @param root [String, Pathname, #to_s, nil]
  #     The root for any patterns that need it (e.g. gitignore patterns starting with `/`),
  #     defaults to the current directory when nil.
  #   @param format [:gitignore, :glob_gitignore, :exact, :shebang]
  #     The format of the rules
  #   @return [PathList]
  #     a new PathList
  # @overload ignore(patterns_from_file:, format: :gitignore, root: nil)
  #   @param patterns_from_file [String, Pathname, #to_s]
  #     A file to read the list of patterns from, with each pattern on its own line
  #   @param root [String, Pathname, #to_s, nil]
  #     The root for any patterns that need it (e.g. gitignore patterns starting with `/`),
  #     when nil, defaults to the directory containing the patterns_from_file file.
  #   @param format [:gitignore, :glob_gitignore, :exact, :shebang]
  #     The format of the patterns, see {PatternParser::Gitignore},
  #     {PatternParser::GlobGitignore},
  #     {PatternParser::ExactPath},
  #     {PatternParser::Shebang}
  #   @return [PathList]
  #     a new PathList
  # @example
  #   PathList.ignore('*.md', root: './docs').ignore(patterns_from_file: '.dockerignore')
  #   PathList.ignore('/bin').ignore!("ruby", format: :shebang)
  #   PathList.gitignore.ignore('spec', format: :exact)
  # @see #ignore
  # @see #ignore!
  def self.ignore(*patterns, patterns_from_file: nil, format: :gitignore, root: nil)
    new.ignore!(*patterns, patterns_from_file: patterns_from_file, format: format, root: root)
  end

  # Return a new PathList that filters out files using the given patterns.
  #
  # @overload ignore(*patterns, format: :gitignore, root: nil)
  #   @param patterns [Array<String>]
  #     The list of patterns. Within an array, or as a line-separated string.
  #     The individual pattern format depends on the `format:` param
  #   @param root [String, Pathname, #to_s, nil]
  #     The root for any patterns that need it (e.g. gitignore patterns starting with `/`),
  #     defaults to the current directory when nil.
  #   @param format [:gitignore, :glob_gitignore, :exact, :shebang]
  #     The format of the patterns, see {PatternParser::Gitignore},
  #     {PatternParser::GlobGitignore},
  #     {PatternParser::ExactPath},
  #     {PatternParser::Shebang}
  #   @return [PathList]
  #     a new PathList
  # @overload ignore(patterns_from_file:, format: :gitignore, root: nil)
  #   @param patterns_from_file [String, Pathname, #to_s]
  #     A file to read the list of patterns from, with each pattern on its own line
  #   @param root [String, Pathname, #to_s, nil]
  #     The root for any patterns that need it (e.g. gitignore patterns starting with `/`),
  #     when nil, defaults to the directory containing the patterns_from_file file.
  #   @param format [:gitignore, :glob_gitignore, :exact, :shebang]
  #     The format of the rules
  #   @return [PathList]
  #     a new PathList
  # @example
  #   PathList.ignore('*.md', root: './docs').ignore(patterns_from_file: '.dockerignore')
  #   PathList.ignore('/bin').ignore!("ruby", format: :shebang)
  #   PathList.gitignore.ignore('spec', format: :exact)
  # @see .ignore
  # @see #ignore!
  def ignore(*patterns, patterns_from_file: nil, format: :gitignore, root: nil)
    dup.ignore!(*patterns, patterns_from_file: patterns_from_file, format: format, root: root)
  end

  # Update self to filter out files using the given patterns.
  #
  # @overload ignore!(*patterns, format: :gitignore, root: nil)
  #   @param patterns [Array<String>]
  #     The list of patterns. Within an array, or as a line-separated string.
  #     The individual pattern format depends on the `format:` param
  #   @param root [String, Pathname, #to_s, nil]
  #     The root for any patterns that need it (e.g. gitignore patterns starting with `/`),
  #     defaults to the current directory when nil.
  #   @param format [:gitignore, :glob_gitignore, :exact, :shebang]
  #     The format of the patterns, see {PatternParser::Gitignore},
  #     {PatternParser::GlobGitignore},
  #     {PatternParser::ExactPath},
  #     {PatternParser::Shebang}
  #   @return [self]
  # @overload ignore!(patterns_from_file:, format: :gitignore, root: nil)
  #   @param patterns_from_file [String, Pathname, #to_s]
  #     A file to read the list of patterns from, with each pattern on its own line
  #   @param root [String, Pathname, #to_s, nil]
  #     The root for any patterns that need it (e.g. gitignore patterns starting with `/`), when nil,
  #     defaults to the directory containing the patterns_from_file file.
  #   @param format [:gitignore, :glob_gitignore, :exact, :shebang]
  #     The format of the rules
  #   @return [self]
  # @example
  #   PathList.ignore('*.md', root: './docs').ignore(patterns_from_file: '.dockerignore')
  #   PathList.ignore('/bin').ignore!("ruby", format: :shebang)
  #   PathList.gitignore.ignore('spec', format: :exact)
  # @see .ignore
  # @see #ignore
  def ignore!(*patterns, patterns_from_file: nil, format: :gitignore, root: nil)
    and_matcher(PatternParser.build(patterns, patterns_from_file: patterns_from_file, format: format, root: root))
  end

  # @!group Only methods

  # Return a new PathList that selects only those files that match given patterns.
  #
  # @overload only(*patterns, format: :gitignore, root: nil)
  #   @param patterns [Array<String>, Array<Array<String>>, String]
  #     The list of patterns. Within an array, or as a line-separated string.
  #     The individual pattern format depends on the `format:` param
  #   @param root [String, Pathname, #to_s, nil]
  #     The root for any patterns that need it (e.g. gitignore-style patterns starting with `/`),
  #     defaults to the current directory when nil.
  #   @param format [:gitignore, :glob_gitignore, :exact, :shebang]
  #     The format of the patterns, see {PatternParser::Gitignore},
  #     {PatternParser::GlobGitignore},
  #     {PatternParser::ExactPath},
  #     {PatternParser::Shebang}
  #   @return [PathList]
  #     a new PathList
  # @overload only(patterns_from_file:, format: :gitignore, root: nil)
  #   @param patterns_from_file [String, Pathname, #to_s]
  #     A file to read the list of patterns from, with each pattern on its own line
  #   @param root [String, Pathname, #to_s, nil]
  #     The root for any patterns that need it (e.g. gitignore-style patterns starting with `/`),
  #     when nil, defaults to the directory containing the patterns_from_file file.
  #   @param format [:gitignore, :glob_gitignore, :exact, :shebang]
  #     The format of the rules
  #   @return [PathList]
  #     a new PathList
  # @example
  #   PathList.only('*.md', root: './docs').ignore('CHANGELOG.md')
  #   PathList.only(patterns_from_file: './files_to_copy.txt', exact: true)
  #   PathList.only(['bin', 'lib', 'exe', 'README.md', 'LICENSE'])
  # @see #only
  # @see #only!
  def self.only(*patterns, patterns_from_file: nil, format: :gitignore, root: nil)
    new.only!(*patterns, patterns_from_file: patterns_from_file, format: format, root: root)
  end

  # Return a new PathList that selects only those files that match given patterns.
  #
  # @overload only(*patterns, format: :gitignore, root: nil)
  #   @param patterns [Array<String>, Array<Array<String>>, String]
  #     The list of patterns. Within an array, or as a line-separated string.
  #     The individual pattern format depends on the `format:` param
  #   @param root [String, Pathname, #to_s, nil]
  #     The root for any patterns that need it (e.g. gitignore-style patterns starting with `/`),
  #     defaults to the current directory when nil.
  #   @param format [:gitignore, :glob_gitignore, :exact, :shebang]
  #     The format of the patterns, see {PatternParser::Gitignore},
  #     {PatternParser::GlobGitignore},
  #     {PatternParser::ExactPath},
  #     {PatternParser::Shebang}
  #   @return [PathList]
  #     a new PathList
  # @overload only(patterns_from_file:, format: :gitignore, root: nil)
  #   @param patterns_from_file [String, Pathname, #to_s]
  #     A file to read the list of patterns from, with each pattern on its own line
  #   @param root [String, Pathname, #to_s, nil]
  #     The root for any patterns that need it (e.g. gitignore-style patterns starting with `/`),
  #     when nil, defaults to the directory containing the patterns_from_file file.
  #   @param format [:gitignore, :glob_gitignore, :exact, :shebang]
  #     The format of the rules
  #   @return [PathList]
  #     a new PathList
  # @example
  #   PathList.only('*.md', root: './docs').ignore('CHANGELOG.md')
  #   PathList.only(patterns_from_file: './files_to_copy.txt', exact: true)
  #   PathList.only(['bin', 'lib', 'exe', 'README.md', 'LICENSE'])
  # @see .only
  # @see #only!
  def only(*patterns, patterns_from_file: nil, format: :gitignore, root: nil)
    dup.only!(*patterns, patterns_from_file: patterns_from_file, format: format, root: root)
  end

  # Update self to select only those files that match given patterns.
  #
  # @overload only!(*patterns, format: :gitignore, root: nil)
  #   @param patterns [Array<String>, Array<Array<String>>, String]
  #     The list of patterns. Within an array, or as a line-separated string.
  #     The individual pattern format depends on the `format:` param
  #   @param root [String, Pathname, #to_s, nil]
  #     The root for any patterns that need it (e.g. gitignore-style patterns starting with `/`),
  #     defaults to the current directory when nil.
  #   @param format [:gitignore, :glob_gitignore, :exact, :shebang]
  #     The format of the patterns, see {PatternParser::Gitignore},
  #     {PatternParser::GlobGitignore},
  #     {PatternParser::ExactPath},
  #     {PatternParser::Shebang}
  #   @return [self]
  # @overload only!(patterns_from_file:, format: :gitignore, root: nil)
  #   @param patterns_from_file [String, Pathname, #to_s]
  #     A file to read the list of patterns from, with each pattern on its own line
  #   @param root [String, Pathname, #to_s, nil]
  #     The root for any patterns that need it (e.g. gitignore-style patterns starting with `/`),
  #     when nil, defaults to the directory containing the patterns_from_file file.
  #   @param format [:gitignore, :glob_gitignore, :exact, :shebang]
  #     The format of the rules
  #   @return [self]
  # @example
  #   PathList.ignore('CHANGELOG.md').only!('*.md', root: './docs')
  #   PathList.only(patterns_from_file: './files_to_copy.txt', exact: true)
  #   PathList.only(['bin', 'lib', 'exe', 'README.md', 'LICENSE'])
  # @see .only
  # @see #only
  def only!(*patterns, patterns_from_file: nil, format: :gitignore, root: nil)
    and_matcher(
      PatternParser.build(
        patterns, patterns_from_file: patterns_from_file, format: format, root: root, polarity: :allow
      )
    )
  end

  # @!group Union methods

  # Return a new PathList that matches any of path_lists.
  #
  # @param path_lists [*PathList]
  # @return [PathList]
  #   a new PathList
  # @example
  #   PathList.union(PathList.only("*.ts"), PathList.only("*.tsx"))
  #   # is equivalent to
  #   PathList.only(["*.ts", "*.tsx"])
  # @see #union
  # @see #union!
  # @see #|
  def self.union(path_list, *path_lists)
    path_list.union(*path_lists)
  end

  # Return a new PathList that matches the receiver OR any of path_lists.
  #
  # @param path_lists [*PathList]
  # @return [PathList]
  #   a new PathList
  # @example
  #   PathList.gitignore.only(["*.js", "*.jsx"]).union(PathList.only("*.ts"), PathList.only("*.tsx"))
  #   # is equivalent to
  #   PathList.gitignore.only(["*.js", "*.jsx", "*.ts", "*.tsx"])
  # @see .union
  # @see #union!
  # @see #|
  def union(*path_lists)
    dup.union!(*path_lists)
  end

  # Return a new PathList that matches the receiver OR other.
  #
  # @param other [PathList]
  # @return [PathList]
  #   a new PathList
  # @example
  #   PathList.gitignore.only("*.rb") | PathList.only("*.sh")
  #   # is equivalent to
  #   PathList.gitignore.only(["*.rb", "*.sh"])
  # @see .union
  # @see #union
  # @see #union!
  def |(other)
    dup.union!(other)
  end

  # Update self with path_lists as alternate matchers.
  #
  # @param other [PathList]
  # @return [self]
  # @example
  #   my_path_list = PathList.new
  #   my_path_list.union!(PathList.only("*.rb"), PathList.ignore("*.py"))
  #   # my_path_list is now equivalent to
  #   PathList.only("*.rb", "*.py")
  # @see .union
  # @see #union
  # @see #|
  def union!(*path_lists)
    self.matcher = Matcher::Any.build([@matcher, *path_lists.map { |l| l.matcher }]) # rubocop:disable Style/SymbolProc

    self
  end

  # @!group Intersection methods

  # Return a new PathList that matches all of path_lists.
  #
  # @param path_lists [*PathList]
  # @return [PathList]
  #   a new PathList
  # @example
  #   PathList.intersection(PathList.only("*.rb"), PathList.ignore("/vendor/"))
  #   # is equivalent to
  #   PathList.only("*.rb").ignore("/vendor/")
  # @see #intersection
  # @see #intersection!
  # @see #&
  def self.intersection(*path_lists)
    new.intersection!(*path_lists)
  end

  # Return a new PathList that matches the receiver AND all of path_lists.
  #
  # @param path_lists [*PathList]
  # @return [PathList]
  #   a new PathList
  # @example
  #   PathList.gitignore.intersection(PathList.only("*.rb"), PathList.ignore("/vendor/"))
  #   # is equivalent to
  #   PathList.gitignore.only("*.rb").ignore("/vendor/")
  # @see .intersection
  # @see #intersection!
  # @see #&
  def intersection(*path_lists)
    dup.intersection!(*path_lists)
  end

  # Return a new PathList that matchers the receiver AND other.
  #
  # @param other [PathList]
  # @return [PathList]
  #   a new PathList
  # @example
  #   PathList.gitignore.only("*.rb") & PathList.ignore("/vendor/")
  #   # is equivalent to
  #   PathList.gitignore.only("*.rb").ignore("/vendor/")
  # @see .intersection
  # @see #intersection
  # @see #intersection!
  def &(other)
    dup.intersection!(other)
  end

  # Update self with path_lists as additional matchers
  #
  # @param other [PathList]
  # @return [self]
  # @example
  #   my_path_list = PathList.gitignore
  #   my_path_list.intersection!(PathList.only("*.rb"), PathList.ignore("/vendor/"))
  #   # my_path_list is now equivalent to
  #   PathList.gitignore.only("*.rb").ignore("/vendor/")
  # @see .intersection
  # @see #intersection
  # @see #&
  def intersection!(*path_lists)
    and_matcher(Matcher::All.build(path_lists.map { |l| l.matcher })) # rubocop:disable Style/SymbolProc
  end

  # @!group Querying methods

  # Check if a single path would be yielded by {#each}
  #   This will always be false if the path is a directory, or doesn't exist.
  #   If you want to match directories or hypothetical paths, use {#match?}
  # @see #match?
  # @param [String, Pathname, #to_s] path
  #   relative or absolute path to check
  # @return [Boolean]
  # @example
  #   PathList.include?("relative/path")
  #   PathList.include?("./relative/path")
  #   PathList.include?("/absolute/path")
  #   PathList.include?("~/user/path")
  #   PathList.include?(Pathname.new("/stdlib/pathname"))
  #
  #   # because this is aliased as `===`
  #   # PathList can be used in case statements.
  #   case my_path
  #   when PathList.gitignore
  #     "would be matched by git ls-files"
  #   when PathList.only("*.rb")
  #     "would be matched by Dir.glob('**/*.rb')"
  #   end
  def include?(path)
    full_path = PathExpander.expand_path_pwd(path)
    candidate = Candidate.new(full_path)
    return false if !candidate.exists? || candidate.directory?

    recursive_match?(candidate.parent, dir_matcher) &&
      file_matcher.match(candidate) == :allow
  end
  alias_method :member?, :include?
  alias_method :===, :include?

  # @return [Proc]
  #   {#include?} as a proc
  # @see #include?
  # @example
  #   ["my/path", "my/other/path"].select(&PathList.gitignore)
  def to_proc
    method(:include?).to_proc
  end

  # Looser than {#include?}, it also returns true for directories that could
  # theoretically contain files in the PathList, or even for paths that don't
  # exist but could hypothetically match the PathList.
  # @see #include?
  #
  # @param [String, Pathname, #to_s] path
  #   relative or absolute path to check
  # @param [nil, true, false] directory
  #   override whether to match this file as a directory or not.
  #   When `nil`, will check the filesystem for what this path actually is,
  #   before defaulting to `false` if the path is inaccessible or nonexistent.
  # @param [String, nil] content
  #   override the content of the file when checking shebang rules.
  #   When nil, will check the filesystem for the actual first line if necessary,
  #   defaulting to an empty string if the path is inaccessible or nonexistent.
  # @return [Boolean]
  # @example
  #   PathList.include?('my_directory/my_file') # given this returns true
  #   PathList.include?('my_directory') # returns false, as it's a directory, not a file that would be yielded by each.
  #   PathList.match?('my_directory') # returns true, because it *could contain* 'my_file'
  #   PathList.match?('my_directory/my_file', directory: true) # you can lie about whether a file is a directory
  #   PathList.match?('my_directory/my_file', content: '#!/bin/ruby') # you can also just lie about the content
  def match?(path, directory: nil, content: nil)
    full_path = PathExpander.expand_path_pwd(path)
    content = content.slice(/\A#!.*$/)&.downcase || '' if content
    candidate = Candidate.new(full_path, directory, content)

    recursive_match?(candidate.parent, dir_matcher) &&
      @matcher.match(candidate) == :allow
  end

  # yields each of the filenames not ignored by the `PathList` in a non-specific order, recursively.
  #
  # This works like git ls-files, in that it only returns files, not directories,
  # and it treats symlinks as regular files, even symlinks to directories.
  #
  # This `each` method allows all `Enumerable` methods to work, `#to_a` or `#filter_map` or etc.
  #
  # Will return an `Enumerator` when not given a block.
  #
  # @param [String, Pathname, #to_s] root (Dir.pwd)
  #   relative or absolute path to start from
  # @yieldparam [String] path
  #   relative path from `root`
  # @return [self, Enumerator<String>]
  # @example
  #   PathList.gitignore.each { |path| puts "#{path} is not ignored by git" }
  #   PathList.gitignore.each("./within/a/subdirectory") { |path| puts path }
  #   PathList.each("/") { |path| puts path } # traverse a whole filesystem?
  #   PathList.gitignore.each.with_object({}) { |path, hash| hash[path] = true }
  #   PathList.gitignore.each("./within/a/subdirectory").select { |path| ::File.symlink?(path) }
  def each(root = '.', &block)
    return enum_for(:each, root) unless block

    root = PathExpander.expand_path_pwd(root)
    root_candidate = Candidate.new(root)
    return self unless root_candidate.exists?
    return self unless recursive_match?(root_candidate.parent, dir_matcher)

    relative_root = root == '/' ? root : "#{root}/"

    recursive_each(root_candidate, relative_root, dir_matcher, file_matcher, &block)

    self
  end

  protected

  attr_reader :matcher

  private

  def recursive_each(candidate, relative_root, dir_matcher, file_matcher, &block)
    if candidate.directory?
      return unless dir_matcher.match(candidate) == :allow

      candidate.child_candidates.each do |child|
        recursive_each(child, relative_root, dir_matcher, file_matcher, &block)
      end
    else
      return unless file_matcher.match(candidate) == :allow

      yield(candidate.full_path.delete_prefix(relative_root))
    end
  end

  def recursive_match?(candidate, matcher)
    return true unless candidate

    recursive_match?(candidate.parent, matcher) && matcher.match(candidate) == :allow
  end

  def and_matcher(new_matcher)
    self.matcher = Matcher::All.build([@matcher, new_matcher])

    self
  end

  def matcher=(new_matcher)
    @matcher = new_matcher
    @dir_matcher = nil
    @file_matcher = nil
  end

  def dir_matcher
    @dir_matcher ||= @matcher.dir_matcher
  end

  def file_matcher
    @file_matcher ||= @matcher.file_matcher
  end
end
