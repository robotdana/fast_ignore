## v1.0.0.rc1
### Changed
- Major api change to make this 1.0.0
  - New name! FastIgnore is now PathList
  - You now chain rulesets rather than building them from a set of kwargs
    - FastIgnore.new(gitignore: true) is now PathList.gitignore
    - FastIgnore.new(include_rules: "rule") is now PathList.only("rule")
    - FastIgnore.new(argv_rules: "rule") is now PathList.only("rule", format: :glob_gitignore)
    - FastIgnore.new(include_files: "file") is now PathList.only(from_file: "file")
    - FastIgnore.new(ignore_rules: "rule") is now PathList.ignore("rule")
    - FastIgnore.new(ignore_files: "file") is now PathList.ignore(from_file: "file")
    - FastIgnore.new(ignore_rules: "rule", include_rules: "rule", gitignore: true) is now PathList.ignore("rule").only("rule").gitignore
  - Shebang rules are now not mixed in with other rules
    - FastIgnore.new(include_rules: "#!: ruby") is now PathList.only("ruby", format: :shebang)
  - root for walking the file system can be set at each call time, rather than initialize time
    - FastIgnore.new(root: "./subdir").each is now PathList.each("./subdir")
    - root for each set of patterns is still handled at PathList.only or PathList.ignore time and can be set independently
  - Dir.chdir can now happen within PathList.each block
  - FastIgnore.allowed? is split into PathList.include? and PathList.match? to be closer to ruby expectations
    - include? is for when you just want the 'would this be in the .to_a output'. it excludes directories, and non-existent files
    - match? is for when you want to test a hypothetical file or directory against the patterns, it can be given directory: or content: to override those values.
  - Almost the entire codebase has been refactored to allow for these changes
### Added
  - PathLists can be joined with .intersection or .union
    - PathList.intersection(PathList.only("rule"), PathList.only("other rule"))
    - PathList.union(PathList.only("rule"), PathList.only("other rule"))

### Removed
- Drop support for ruby 2.5 as its been eol for a while
- Remove deprecated `follow_symlinks:` code.

### Fixed
- Fix the order of reading .gitignore files in sub directories that override rules in outer directories
  now it matches git behaviour of appending the files from the outside in
- fix an issue where `include_directories: true` would match ary directory that could potentially contain files that match (most egregiously repo ancestors). now it only matches directories that are explicitly matched by rules
- a negated include rule that matches a directory will now be respected, even if other rules in the file could be in any directory

## v0.17.4 - 2022-04-30
### Changed
- Lots of refactoring that _should_ have no effect on behaviour
### Deprecated
- Deprecated `follow_symlinks:`, it's inaccurately named and awkward.
  This might have some performance regression. we'll improve more than we lost after the deprecations are gone entirely.


## v0.17.3 - Never released

### Fixed
- Add fuzz tests, fix a couple more edge cases it revealed:
  - `~not_a_user` will be considered literal rather than raising an error, `~a_user` will continue to be expanded to the home directory of `a_user` when used in an `argv_rules:` or `allowed?`
  - an `include_rule:` with a trailing `/` was raising a FrozenError in some circumstances.

## v0.17.2 - 2022-03-19
### Changed
- Tiny performance improvements from rubocop-performance's suggestions
### Removed
- Remove unnecessary backport code that was leftover when support for 2.4 was dropped

## v0.17.1 - 2022-03-19
### Fixed
- fix handling of backward character classes `[z-a]`
  previously this raised a RegexpError, but git just considered it to be identical to `[z]`, now we match the git behaviour (but why would you ever do this?, i only found it because of the fuzz spec in the `leftovers` gem)

## v0.17.0 - 2022-03-03
### Added
- allow overriding `exists:` in `allowed?`
- allow setting `include_directories: true` in `allowed?`
- add ruby 3.1 to the test matrix
### Changed
- slight performance improvements of the shebang rule matcher loading the first line
### Removed
- drop support for ruby 2.4
### Fixed
- subsequent calls to `allowed?` with the same path but different `directory:` or `content:` arguments won't potentially mess up the cache

## v0.16.1 - 2021-12-11
### Fixed
- respect GIT_CONFIG_SYSTEM, GIT_CONFIG_NOSYSTEM and GIT_CONFIG_GLOBAL env vars the same way git does
- make the tests more resilient to whatever global config is going on.

## v0.16.0 - 2021-12-09
### Added
- Entirely rewrite the way that git config files are read. previously it was just a regexp. now we actually parse git config files according to the same rules as git.
- Add ruby 3 to the test matrix

## v0.15.2 - 2020-11-18
### Fixed
- Updated methods with multiple `_` arguments to have different names to make sorbet happy

## v0.15.1 - 2020-10-25
### Changed
- Updated dependencies to allow running on ruby 3.0.0.preview1

## v0.15.0 - 2020-07-18
### Added
- mentioned submodules & sparse checkout in the readme as yet another thing git does that this project doesn't because submodule details are hidden in the git index.
### Changed
- major refactoring of the regexp builder that shouldn't have any behaviour implications but should make development easier (e.g. seeing some unhandled edge cases).
- improved speed of repos with many sub-gitignore files
### Fixed
- fixed a handful of character class edge cases to match git behavior
  - mostly ranges with - or / as one end of the range

## v0.14.0 - 2020-06-28
### Added
- add `FastIgnore#to_proc` for no good reason
### Changed
- significant performance improvements ~50% faster

## v0.13.0 - 2020-06-06
### Changed
- Attempt to improve documentation structure
### Removed
- Remove `gitignore: true` raising `Errno::ENOENT` if root:/.gitignore didn't exist. I can't think of a use. Now `gitignore: true` is just the default behaviour.
### Fixed
- Don't ignore `.git` if `gitignore: false`.

## v0.12.1 - 2020-05-24
### Fixed
- Reads all relevant git config files when finding a global .gitignore

## v0.12.0 - 2020-05-04
### Added
- Reads all relevant gitignore files (nested .gitignore files, global .gitignore referred to in .gitconfig, and .git/info/exclude)

## v0.11.0 - 2020-05-02
### Added
- optionally pass directory: and content: into allowed? if these are already loaded.
### Changed
- major performance improvement (use regexp rather than fnmatch)

## v0.10.2 - 2020-04-26
### Added
- add FastIgnore#=== as an alias for FastIgnore#allowed? so that FastIgnore objects can be used for case statements.
### Fixed
- Fix shebangs in non-pwd-root situations

## v0.10.1 - 2020-04-22
### Added
- Add option to follow symlinks (turns out i needed it)
### Changed
- performance improvements

## v0.10.0 - 2020-04-21
### Added
- new shebang pattern (#!:), the previous version was extremely janky.
  - now you can ignore by shebang pattern
- root can be given as a path relative to PWD
### Changed
- documentation improvements
### Fixed
- patterns with middle slashes are anchored to the root (like the gitignore documentation, now that it more clearly explains)
- symlinks aren't followed when deciding if a path is a directory or not (this now matches git)
- includes with 'a/**/d' now matches a/b/c/d properly

## v0.9.0 - 2020-04-19
### Changed
- speed improvements, which may break things (Specifically, only using relative paths internally, is about 30% faster (depending on root depth))
- using a `ignore_files:` or `include_files:` that are outside the `root: (default $PWD)` will now raise an error.
### Removed
- remove deprecated `gitignore:` a path (e.g. `gitignore: '/path/to/gitignore'`). please use `gitignore: false, ignore_files: '/path/to/gitignore'` instead.

## v0.8.3 - 2020-04-18
### Fixed
- fix `ignore_rules` not matching directories when using `include_shebangs:`

## v0.8.2 - 2020-04-18
### Fixed
- fix `include_rules` not matching filenames with no extension when using `include_shebangs:`

## v0.8.1 - 2020-04-17
### Added
- `include_shebangs:` can be given non array value

## v0.8.0 - 2020-04-17
### Added
- add coverage to the pipeline. removed some methods, added some tests, and now we have 100% test coverage
### Deprecated
- deprecate using `gitignore: '/path/to/gitignore'`. please use `gitignore: false, ignore_files: '/path/to/gitignore'` instead.
### Removed
- drop support for ruby 2.3. My plan is to only support supported ruby versions

## v0.7.0 - 2020-02-28
### Added
- add `include_shebangs:` which filters by shebangs

## v0.6.0 - 2020-02-26
### Added
- nicer argv handling
  - add `argv_rules:` option, which resolves paths and considers everything that doesn't start with a `*` to start with a `/`
- slightly more realistic version comparison just in case someone releases ruby 2.10
- can be run with --disable-gems
### Changed
- combine the different includes methods and files using AND
- `.allowed?` now more exactly matches `.each`, it returns false for directories and unreadable files.

## v0.5.2 - 2020-02-20
### Changed
- performance improvements

## v0.5.1 - 2020-02-12
### Fixed
- restore `.allowed?`. now i have tests for it. oops

## v0.5.0 - 2020-02-12
### Changed
- some performance improvements
- it's a big refactor, sorry if i broke something
### Removed
- remove deprecated `:rules` and `:files` arguments
### Fixed
- ! is now evaluated in sequence for include_rules

## v0.4.1 - 2019-10-06
### Fixed
- oops i did a regexp wrong

## v0.4.0 - 2019-10-05
### Added
- include_rules support
### Deprecated
- to make room for this, `:rules` and `:files` keyword arguments are deprecated.
  Please use `:ignore_rules` and `:ignore_files` instead.

## v0.3.3 - 2019-09-27
### Changed
- some performance improvements. maybe

## v0.3.2 - 2019-09-20
### Fixed
- handle soft links to nowhere

## v0.3.1 - 2019-08-09
### Changed
- upgrade rubocop version requirement to avoid github security warning

## v0.3.0 - 2019-08-09
### Added
- Supports 2.3 - 2.6

## v0.2.0 - 2019-04-07
### Added
- Can override the path to the gitignore file, using `FastIgnore.new(gitignore: path)`
- Mention FastIgnore#allowed? in the documentation.
### Changed
- Considers rules relative to the location of the gitignore file instead of just relative to PWD

## v0.1.0 - 2019-04-06
Initial Release
