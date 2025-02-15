# PathList

[![Gem Version](https://badge.fury.io/rb/path_list.svg)](https://rubygems.org/gems/path_list)

Find and list files according to various rules, including full support for .gitignore files.

```ruby
PathList.gitignore == `git ls-files`.split("\n")
```

## Features

- **Speed**
- a ruby implementation of `git ls-files` without requiring git to be installed
- a gitignore-style denylist and *allowlist*.
- a glob-like format for unsurprising ARGV use
- shebang matching for extensionless files

Supports ruby 2.5-3.4.x & jruby

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

- Build a [`PathList`](docs/PathList.html) by chaining [`.gitignore`](docs/PathList#gitignore-instance_method) [`.only`](docs/PathList#only-instance_method), [`.ignore`](docs/PathList#ignore-instance_method), and combining these chains with [`.union`](docs/PathList#union-instance_method), or [`.intersection`](docs/PathList#gitignore-instance_method)

- Yield each of the files not ignored by your PathList with [`.each`](docs/PathList#each-instance_method) or any other enumerable methods.
- Test if a file path would be yielded by this PathList with [`.include?` or `===`](docs/PathList#include%3F-instance_method).
- Test if a file or directory path would hypothetically be matchable by your PathList with [`.match?`](docs/PathList#match%3F-instance_method).

```ruby
PathList.gitignore.each { |file| puts "#{file} is not ignored by git" }
PathList.gitignore.filter_map { |file| ::File.read(file) if ::File.readable?(file) }
PathList.only('*.rb', '!config/').each { |file| puts "#{file} is a ruby file not in the config directory" }
PathList.ignore(patterns_from_file: '.dockerignore').each { |file| puts "#{file} would be copied with dockerfile COPY" }
PathList.intersection(PathList.gitignore, PathList.union(PathList.only('*.rb'), PathList.only('*.py')))

PathList.gitignore.include?("is/this/file/gitignored")
PathList.gitignore.match?("is/this")
PathList.gitignore.match?("is/this/hypothetical/directory", directory: true)
```

See the [full PathList documentation](docs/PathList).

## Limitations

- PathList matches patterns according to the case sensitively of the current directory when it was loaded. (git depends on the value of core.ignorecase).
- PathList always outputs paths as literal UTF-8 characters. (git depends on your core.quotepath setting but by default outputs non ascii paths with octal escapes surrounded by quotes).
- git has a system-wide config file installed at `$(prefix)/etc/gitconfig`, where `prefix` is defined for git at install time. PathList assumes that it will always be `/usr/local/etc/gitconfig`. if it's important your system config file is looked at, as that's where you have the core.excludesfile defined (why?), use git's built-in way to override this by setting this environment variable `export GIT_CONFIG_SYSTEM='/the/actual/location'`.
- Because git looks at its own index objects and PathList looks at the filesystem there may be some differences between `PathList.gitignore` and `git ls-files`. To avoid these differences you may want to use the [`git_ls`](https://github.com/robotdana/git_ls) gem instead which parses the .git/index file.
  - Tracked files that were committed before the matching ignore pattern was committed, or were added with `git add --force`, will be returned by `git ls-files`, but not by `PathList.gitignore`.
  - Untracked files will be returned by `PathList.gitignore`, but not by `git ls-files`
  - On a case insensitive file system, with files in the repo that differ only by case, `git ls-files` will include all case variations, while `PathList.gitignore` will only include whichever variation git placed in the file system.
  - `PathList.gitignore` will only return the files actually on the file system when using `git sparse-checkout`, `git ls-files` will return all of them

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
