# FastIgnore

[![travis](https://travis-ci.org/robotdana/fast_ignore.svg?branch=master)](https://travis-ci.org/robotdana/fast_ignore)

Filter a directory tree using a .gitignore file. Recognises all of the [gitignore rules](https://www.git-scm.com/docs/gitignore#_pattern_format) ([except one](#known-issues))

```ruby
FastIgnore.new(relative: true).sort == `git ls-files`.split("\n").sort
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'fast_ignore'
```

And then execute:
```sh
$ bundle
```
Or install it yourself as:
```sh
$ gem install fast_ignore
```

## Usage

```ruby
FastIgnore.new.each { |file| puts "#{file} is not ignored by the .gitignore" }
```

Like many other enumerables, `FastIgnore#each` can return an enumerator

```ruby
FastIgnore.new.each.with_index { |file, index| puts "#{file}#{index}" }
```

By default, FastIgnore will return full paths. To return paths relative to the current working directory, use:

```ruby
FastIgnore.new(relative: true).to_a
```

You can specify other gitignore-style files to ignore as well. These rules will be appended after the gitignore file in order (order matters for negations)
```ruby
FastIgnore.new(files: '/absolute/path/to/my/ignore/file').to_a
FastIgnore.new(files: ['/absolute/path/to/my/ignore/file', '/and/another']).to_a
```
You can also supply an array of rule lines. These rules will be appended after the gitignore and any other files in order (order matters for negations)
```ruby
FastIgnore.new(rules: '.DS_Store').to_a
FastIgnore.new(rules: ['.git', '.gitkeep']).to_a
```

To only use another ignore file or set of rules, and not try to load a gitignore file:
```ruby
FastIgnore.new(files: 'absolute/path/to/my/ignore/file', gitignore: false)
FastIgnore.new(rules: %w{my*rule /and/another !rule}, gitignore: false)
```

By default, FastIgnore will look in the directory the script is run in (`PWD`) for a gitignore file. If it's somewhere else:
```ruby
FastIgnore.new(gitignore: '/absolute/path/to/.gitignore').to_a
```
Note that the location of the .gitignore file will affect things like rules beginning with `/` or ending in `/**`

To check if a single file is allowed, use
```ruby
FastIgnore.new.allowed?('/absolute/path/to/file')
```

## Known issues
- Doesn't take into account project excludes in `.git/info/exclude`
- Doesn't take into account globally ignored files in `git config core.excludesFile`.
- Doesn't follow this rule in the gitignore documentation because I don't understand what it means that isn't covered by other rules:

  > [If the pattern does not contain a slash /, Git treats it as a shell glob pattern and checks for a match against the pathname relative to the location of the `.gitignore` file (relative to the toplevel of the work tree if not from a `.gitignore` file)](https://www.git-scm.com/docs/gitignore#_pattern_format)

  if someone can explain it with examples [make an issue please](https://github.com/robotdana/fast_ignore/issues/new)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/robotdana/fast_ignore.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
