# PathList

[![Gem Version](https://badge.fury.io/rb/path_list.svg)](https://rubygems.org/gems/path_list)

Quickly and native-ruby-ly parse gitignore files and find all non-ignored files.

```ruby
PathList.gitignore.sort == `git ls-files`.split("\n").sort
```

## Features

- **Fast** (faster than using `` `git ls-files`.split("\n") `` for small repos (because it avoids the overhead of ``` `` ```))

- with `PathList.gitignore`
  - supports all [gitignore rule patterns](https://git-scm.com/docs/gitignore#_pattern_format)
  - **doesn't require git to be installed**
  - reads .gitignore in all subdirectories
  - reads .git/info/excludes
  - reads the global gitignore file mentioned in your git config

- supports gitignore-style denylist and *allowlist*. ([`PathList.ignore`, `PathList.only`](#ignore_only))
- supports a glob-like format for unsurprising ARGV use ([`PathList.only(ARGV, format: :glob)`](#format_glob))
- supports matching by shebang rather than filename for extensionless files [`PathList.only("ruby", format: :shebang)`](#format_shebang)

- Supports ruby 2.7-3.2.x & jruby

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'path_list'
```

And then execute:
```sh
$ bundle
```
Or install it yourself as:
```sh
$ gem install path_list
```

## Usage

- Build a `PathList` by chaining [`.gitignore`](#gitignore) [`.only`](#ignore_only), [`.ignore`](#ignore_only), and combining these chains with [`.union`](#union), or [`.intersection`](#intersection)

- Yield each of the files not ignored by your PathList with [`.each`](#each_map_to_a_etc) or other enumerable methods.
- Test if a file path would be yielded by this PathList with [`.include?` or `===`](#include).
- Test if a file or directory path would hypothetically be matchable by your PathList with [`.match?`](#match).

```ruby
PathList.gitignore.each { |file| puts "#{file} is not ignored by git" }
PathList.only('*.rb', '!config/').each { |file| puts "#{file} is a ruby file not in the config directory" }
PathList.ignore(read_from_file: '.dockerignore').each { |file| puts "#{file} would be copied with dockerfile COPY" }

PathList.gitignore.include?("is/this/file/gitignored")
PathList.gitignore.match?("is/this")
```

**Note: If you want use the same PathList match rules more than once, save the instance to a variable to avoid having to read and parse the patterns over and over again**

### `each`, `map`, `to_a`, etc...

`each` will successively yield each of the files not ignored by your PathList.

```ruby
PathList.gitignore.each { |file| puts "#{file} is not ignored by git" }
```

`each` can return an enumerator allowing even more chaining:

```ruby
PathList.gitignore.each.with_index { |file, index| puts "#{file}#{index}" }
```

Give `each` a path to start from instead of defaulting to the current working directory:

```ruby
PathList.gitignore.each("./within/a/subdirectory") { |file| puts "#{file}#{index}" }
PathList.each("/") { |file| puts "#{file}" } # traverse a whole filesystem?
```

A PathList instance is an Enumerable and responds to all Enumerable methods:

```ruby
PathList.gitignore.to_a
PathList.gitignore.map { |file| file.upcase }
```

### `#include?`

Check if a single path would be yielded

```ruby
PathList.include?("relative/path")
PathList.include?("./relative/path")
PathList.include?("/absolute/path")
PathList.include?("~/home/path")
PathList.include?(Pathname.new("/stdlib/pathname"))
```

This is also available as `===` so you can use a PathList instance in case statements.
```ruby
gitignore_matcher = PathList.gitignore
ruby_matcher = PathList.only("*.rb")

case my_path
when gitignore_matcher then "git ls-files"
when ruby_file_matcher then "Dir.glob('**/*.rb')"
end
```

### `#match?`

Looser than [`include?`](#include), it also returns true for directories that could contain files in the PathList,
or even for paths that don't exist but could hypothetically match the PathList.

```ruby
PathList.include?('my_directory/my_file') # given this returns true
PathList.include?('my_directory') # returns false, as it's a directory, not a file that would be yielded by each.
PathList.match?('my_directory') # returns true, because it *could contain* 'my_file'
PathList.match?('my_directory/my_file', directory: true) # you can lie about whether a file is a directory
PathList.match?('my_directory/my_file.sh', content: '#!/bin/ruby') # you can also just lie about the content
```

#### `match?(path, directory: true|false|nil)`

default: `nil`

By default, PathList will check that path on the file system, and if it can't be read, or doesn't exist it will assume  this is not a directory. (symlinks aren't considered directories even if they point to directories)

If you want to lie about whether something is a directory, pass `true` or `false` to `directory:`.

```ruby
PathList.match?("path", directory: false) # will match as a file
PathList.match?("path", directory: true) # will as a directory
PathList.match?("path", directory: nil) # will match as its reality, or default to as a file
```

#### `match?(path, content: String)`

default: `nil`

When checking a shebang rule, by default PathList will read the first line of that file, and if it can't be read, or doesn't exist it will assume it's empty.

If you want to lie about the file content, pass a string to `content:`.

```ruby
PathList.match?("path", content: "#!/usr/bin/env ruby\n\nputs 'hello'") # will match as ruby shebang
PathList.match?("path", content: "#!/usr/bin/env bash\n\necho 'hello'") # will match as bash shebang
PathList.match?("path", content: nil) # will match as whatever the file content is on the filesystem, or an empty file
```

### `gitignore`

This is intended to mimic the behaviour of `git ls-files`.

Because `git ls-files` uses its own index rather than what's actually on the file system it might not be a perfect match, [see these limitations](#limitations). This will also probably end up with differently sorted entries.

When using `gitignore`: the .gitignore file in the current directory is loaded, plus any .gitignore files in its subdirectories, the global git ignore file as described in git config, and .git/info/exclude.

```ruby
PathList.gitignore.to_a
```
### `ignore`, `only`:

Additional rules or files containing rules, either as a path or an array of paths to ignore or only match.

`ignore` is a denylist like .gitignore, and `only` is an allowlist, and will ignore everything else.

You can chain these, and any matched files must pass each of these constraints.


You can give rules directly:
```ruby
# these are all equivalent:
PathList.only("tmp/*\n!tmp/.keep\nlog").to_a
PathList.only("tmp/*", "!tmp/.keep", "log").to_a
PathList.only(["tmp/*", "!tmp/.keep", "log"]).to_a
```

An empty `.only([])` will be discarded and won't affect results.

There is an equivalent bang method available:

```ruby
# these are identical
path_list = PathList.new
path_list.ignore!("tmp/*", "!tmp/.keep")
path_list.ignore!("log/*", "!log/.keep")
path_list.only!("*.*")

PathList.ignore("tmp/*", "!tmp/.keep").ignore("log/*", "!log/.keep").only("*.*")
```

#### `root:`

Use `root:` to define the location for parsing rules beginning with or containing `/`
```ruby
PathList.ignore("/cache/*", root: "tmp").to_a
```

#### `read_from_file:`

Instead of listing rules themselves, can specify other gitignore-style files to parse for only/ignore rules.

```ruby
PathList.only(read_from_file: './subdir/.dockerignore').to_a
PathList.ignore(read_from_file: '.prettierignore').to_a
```

By default, the location of the files is the root for any rules beginning with or containing `/` when using the :gitignore format. you can override this with `root:`.
Also, Relative paths are relative to the `root:` directory (defaulting to the current directory).

```ruby
PathList.ignore(read_from_file: '.dockerignore', root: './subdir').to_a
```

#### format: :gitignore

Use `format:` to choose how to interpret the rule patterns.

The default is `:gitignore`. See [the git documentation](https://git-scm.com/docs/gitignore#_pattern_format) for more details.

This format is used by more than just git, for example `.dockerignore` or `.eslintignore`

```ruby
PathList.ignore('tmp/*', '!tmp/.keep', format: :gitignore)
```

#### format: :shebang

Use `:shebang` to match files *that have no extension* and have this shebang:

```ruby
PathList.only('ruby', format: :shebang, root: 'bin').to_a
```

will match files in bin with `#!/bin/ruby` or `#!/usr/bin/ruby` or `#!/usr/bin/ruby -w`
Only exact substring matches are available, There's no special handling of * or / or etc.

#### format: :glob

Use `:glob` when dealing with humans and `ARGV` values with glob expectations, but with gitignore style negation and better performance.

It handles rules that are absolute paths, and paths beginning with `~`, `../` and `./` (with and without `!`).
This means rules beginning with `/` are absolute. Not relative to the root directory.
Additionally it assumes all other rules are relative to the [`root:`](#root) director unless they begin with `*` (or `!*`).
After this the rule will be handled like any other gitignore rule.

```ruby
PathList.only(ARGV, format: :glob)
PathList.only(
  './relative_to_current_dir',
  '/Users/dana/Projects/my_project/or_an_absolute_path',
  'relative_to_current_dir_not_just_any_descendant',
  '**/any_descendant',
  '!we_can_also_negate',
  format: :glob
).to_a
PathList.only('./relative_to_root_dir', format: :glob, root: './subdir')
```

### .union

by default chained rules combine with AND.

```ruby
PathList.gitignore.only("*.rb").ignore("/vendor/")
```

will be any ruby files not ignored by git, and not in the vendor directory.

To instead combine with OR use `union` chain.

```ruby
PathList.only("*.rb").union(PathList.only("ruby", format: :shebang))
```

this would match ruby files that have an .rb extension or a ruby shebang, that aren't ignored by git.

```ruby
PathList.only("*.rb") | PathList.only("ruby", format: :shebang)
```
You can also define unions with the `|` operator.

### intersection

merge other PathList instances into one matcher

```ruby
# these are equivalent
PathList.gitignore.intersection(PathList.only("*.rb"), PathList.ignore("/vendor/"))
PathList.gitignore.only("*.rb").ignore("/vendor/")
```

```ruby
PathList.gitignore.only("*.rb") & PathList.ignore("/vendor/")
```
You can also define intersections with the `&` operator.


## Limitations
- PathList always matches patterns case-insensitively. (git varies by filesystem).
- PathList always outputs paths as literal UTF-8 characters. (git depends on your core.quotepath setting but by default outputs non ascii paths with octal escapes surrounded by quotes).
- git has a system-wide config file installed at `$(prefix)/etc/gitconfig`, where `prefix` is defined for git at install time. PathList assumes that it will always be `/usr/local/etc/gitconfig`. if it's important your system config file is looked at, as that's where you have the core.excludesfile defined (why?), use git's built-in way to override this by adding `export GIT_CONFIG_SYSTEM='/the/actual/location'` to your shell profile.
- Because git looks at its own index objects and PathList looks at the file system there may be some differences between `PathList.gitignore` and `git ls-files`. To avoid these differences you may want to use the [`git_ls`](https://github.com/robotdana/git_ls) gem instead
  - Tracked files that were committed before the matching ignore rule was committed, or were added with `git add --force`, will be returned by `git ls-files`, but not by `PathList.gitignore`.
  - Untracked files will be returned by `PathList.gitignore`, but not by `git ls-files`
  - Deleted files whose deletions haven't been committed will be returned by `git ls-files`, but not by `PathList.gitignore`
  - On a case insensitive file system, with files that differ only by case, `git ls-files` will include all case variations, while `PathList.gitignore` will only include whichever variation git placed in the file system.
  - PathList.gitignore is unaware of submodules and just treats them like regular directories. For example: `git ls-files --recurse-submodules` won't use the parent repo's gitignore on a submodule, while `PathList.gitignore` doesn't know it's a submodule and will.
  - `PathList.gitignore` will only return the files actually on the file system when using `git sparse-checkout`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/robotdana/path_list.

Some tools in the that may help with development:

- `bin/setup`: install development dependencies
- `bundle exec rspec`: run all tests
- `bundle exec rake`: run all tests and linters
- `bin/console`: open a `pry` console with everything required for experimenting
- `bin/compare`: compare the speed and output of `PathList.gitignore` and `git ls-files`.
  (suppressing differences that are because of known [limitations](#limitations))

- `bin/ls [argv_rules]`: the equivalent of `git ls-files`
- `bin/parse`: prints the matchers that have been prepared
- `bin/prof/ls [argv_rules]`: ruby-prof report for `bin/ls`
- `bin/prof/parse [argv_rules]:` ruby-prof report for `bin/parse`
- `bin/time [argv_rules]`: the average time for 30 runs of `bin/ls`

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
