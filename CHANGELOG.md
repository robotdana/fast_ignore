# v0.18.0
- Remove deprecated `follow_symlinks:` code.

# v0.17.4
- Deprecated `follow_symlinks:`, it's inaccurately named and awkward.

- Plus lots of refactoring that _should_ have no effect on behaviour
- Some performance regression due to the deprecation logic. we'll improve more than we lost after the deprecations are gone entirely.

# v0.17.3
- Add fuzz tests, fix a couple more edge cases it revealed:
  - `~not_a_user` will be considered literal rather than raising an error, `~a_user` will continue to be expanded to the home directory of `a_user` when used in an `argv_rules:` or `allowed?`
  - an `include_rule:` with a trailing `/` was raising a FrozenError in some circumstances.

# v0.17.2
- Remove unnecessary backport code that was leftover when support for 2.4 was dropped
- Tiny performance improvements from rubocop-performance's suggestions

# v0.17.1
- fix handling of backward character classes `[z-a]`
  previously this raised a RegexpError, but git just considered it to be identical to `[z]`, now we match the git behaviour (but why would you ever do this?, i only found it because of the fuzz spec in the `leftovers` gem)

# v0.17.0
- allow overriding `exists:` in `allowed?`
- allow setting `include_directories: true` in `allowed?`
- subsequent calls to `allowed?` with the same path but different `directory:` or `content:` arguments won't potentially mess up the cache
- slight performance improvements of the shebang rule matcher loading the first line
- drop support for ruby 2.4
- add ruby 3.1 to the test matrix

# v0.16.1
- respect GIT_CONFIG_SYSTEM, GIT_CONFIG_NOSYSTEM and GIT_CONFIG_GLOBAL env vars the same way git does
- make the tests more resilient to whatever global config is going on.

# v0.16.0
- Entirely rewrite the way that git config files are read. previously it was just a regexp. now we actually parse git config files according to the same rules as git.
- Add ruby 3 to the test matrix

# v0.15.2
- Updated methods with multiple `_` arguments to have different names to make sorbet happy

# v0.15.1
- Updated dependencies to allow running on ruby 3.0.0.preview1

# v0.15.0
- fixed a handful of character class edge cases to match git behavior
  - mostly ranges with - or / as one end of the range
- major refactoring of the regexp builder that shouldn't have any behaviour implications but should make development easier (e.g. seeing those unhandled edge cases).
- improved speed of repos with many sub-gitignore files
- mentioned submodules & sparse checkout in the readme as yet another thing git does that this project doesn't because submodule details are hidden in the git index.

# v0.14.0
- significant performance improvements ~50% faster
- add `FastIgnore#to_proc` for no good reason

# v0.13.0
- Attempt to improve documentation structure
- Remove `gitignore: true` raising `Errno::ENOENT` if root:/.gitignore didn't exist. I can't think of a use. Now `gitignore: true` is just the default behaviour.
- Don't ignore `.git` if `gitignore: false`.

# v0.12.1
- Reads all relevant git config files when finding a global .gitignore

# v0.12.0
- Reads all relevant gitignore files (nested .gitignore files, global .gitignore referred to in .gitconfig, and .git/info/exclude)

# v0.11.0
- major performance improvement (use regexp rather than fnmatch)
- optionally pass directory: and content: into allowed? if these are already loaded.

# v0.10.2
- add FastIgnore#=== as an alias for FastIgnore#allowed? so that FastIgnore objects can be used for case statements.
- Fix shebangs in non-pwd-root situations

# v0.10.1
- Add option to follow symlinks (turns out i needed it)
- performance improvements

# v0.10.0
- patterns with middle slashes are anchored to the root (like the gitignore documentation, now that it more clearly explains)
- new shebang pattern (#!:), the previous version was extremely janky.
  - now you can ignore by shebang pattern
- symlinks aren't followed when deciding if a path is a directory or not (this now matches git)
- documentation improvements
- root can be given as a path relative to PWD
- includes with 'a/**/d' now matches a/b/c/d properly

# v0.9.0
- speed improvements, which may break things (Specifically, only using relative paths internally, is about 30% faster (depending on root depth))
- using a `ignore_files:` or `include_files:` that are outside the `root: (default $PWD)` will now raise an error.
- remove deprecated `gitignore:` a path (e.g. `gitignore: '/path/to/gitignore'`). please use `gitignore: false, ignore_files: '/path/to/gitignore'` instead.

# v0.8.3
- fix `ignore_rules` not matching directories when using `include_shebangs:`

# v0.8.2
- fix `include_rules` not matching filenames with no extension when using `include_shebangs:`

# v0.8.1
- `include_shebangs:` can be given non array value

# v0.8.0
- drop support for ruby 2.3. My plan is to only support supported ruby versions
- add coverage to the pipeline. removed some methods, added some tests, and now we have 100% test coverage
- deprecate using `gitignore: '/path/to/gitignore'`. please use `gitignore: false, ignore_files: '/path/to/gitignore'` instead.

# v0.7.0
- add `include_shebangs:` which filters by shebangs

# v0.6.0
- nicer argv handling
  - add `argv_rules:` option, which resolves paths and considers everything that doesn't start with a `*` to start with a `/`
- combine the different includes methods and files using AND
- slightly more realistic version comparison just in case someone releases ruby 2.10
- can be run with --disable-gems
- `.allowed?` now more exactly matches `.each`, it returns false for directories and unreadable files.

# v0.5.2
- performance improvements

# v0.5.1
- restore `.allowed?`. now i have tests for it. oops

# v0.5.0
- remove deprecated `:rules` and `:files` arguments
- ! is now evaluated in sequence for include_rules
- it's a big refactor, sorry if i broke something
- some performance improvements

# v0.4.1
- oops i did a regexp wrong

# v0.4.0
- include_rules support
- to make room for this, `:rules` and `:files` keyword arguments are deprecated.
  Please use `:ignore_rules` and `:ignore_files` instead.

# v0.3.3
- some performance improvements. maybe

# v0.3.2
- handle soft links to nowhere

# v0.3.1
- upgrade rubocop version requirement to avoid github security warning

# v0.3.0
- Supports 2.3 - 2.6

# v0.2.0
- Considers rules relative to the location of the gitignore file instead of just relative to PWD
- Can override the path to the gitignore file, using `FastIgnore.new(gitignore: path)`
- Mention FastIgnore#allowed? in the documentation.

# v0.1.0
Initial Release
