# frozen_string_literal: true

# rubocop:disable Style/RedundantRegexpEscape

RSpec.describe PathList::GitignoreRuleBuilder do
  let(:method_name) { :build }
  let(:options) { {} }

  def build(rule)
    described_class
      .new(rule, **options)
      .send(method_name)
      .compress_self
  end

  describe '#build' do
    describe 'allow: false, root: nil', skip: 'root: nil is broken' do

      let(:options) { { allow: false, root: nil } }

      describe 'from the gitignore documentation' do
        describe 'A blank line matches no files, so it can serve as a separator for readability.' do
          it { expect(build('')).to be_like PathList::Matchers::Blank }
          it { expect(build(' ')).to be_like PathList::Matchers::Blank }
          it { expect(build("\t")).to be_like PathList::Matchers::Blank }
        end

        describe 'The simple case' do
          it { expect(build('foo')).to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\z}i, false) }
        end

        describe 'A line starting with # serves as a comment.' do
          it { expect(build('#foo')).to be_like PathList::Matchers::Blank }
          it { expect(build('# foo')).to be_like PathList::Matchers::Blank }
          it { expect(build('#')).to be_like PathList::Matchers::Blank }

          it 'must be the first character' do
            expect(build(' #foo'))
              .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)\ \#foo\z}i, false)
          end

          describe 'Put a backslash ("\") in front of the first hash for patterns that begin with a hash' do
            it do
              expect(build('\\#foo'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)\#foo\z}i, false)
            end
          end
        end

        describe 'literal backslashes in filenames' do
          it 'matches an escaped backslash at the end of the pattern' do
            expect(build('foo\\\\'))
              .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\\\z}i, false)
          end

          it 'never matches a literal backslash at the end of the pattern' do
            expect(build('foo\\'))
              .to be_like PathList::Matchers::Blank
          end

          it 'matches an escaped backslash at the start of the pattern' do
            expect(build('\\\\foo'))
              .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)\\foo\z}i, false)
          end

          it 'matches a literal escaped f at the start of the pattern' do
            expect(build('\\foo'))
              .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\z}i, false)
          end
        end

        describe 'Trailing spaces are ignored unless they are quoted with backslash ("\")' do
          it 'ignores trailing spaces in the gitignore file' do
            expect(build('foo  '))
              .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\z}i, false)
          end

          it "doesn't ignore trailing spaces if there's a backslash" do
            expect(build('foo \\ '))
              .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\ \ \z}i, false)
          end

          it 'considers trailing backslashes to never be matched' do
            expect(build('foo\\'))
              .to be_like PathList::Matchers::Blank
          end

          it "doesn't ignore trailing spaces if there's a backslash before every space" do
            expect(build('foo\\ \\ '))
              .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\ \ \z}i, false)
          end

          it "doesn't ignore just that trailing spaces if there's a backslash before the non last space" do
            expect(build('foo\\  '))
              .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\ \z}i, false)
          end
        end

        describe 'If the pattern ends with a slash, it is removed for the purpose of the following description' do
          describe 'but it would only find a match with a directory' do
            # In other words, foo/ will match a directory foo and paths underneath it,
            # but will not match a regular file or a symbolic link foo
            # (this is consistent with the way how pathspec works in general in Git).

            it 'ignores directories but not files or symbolic links that match patterns ending with /' do
              expect(build('foo/'))
                .to be_like PathList::Matchers::MatchIfDir.new(
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\z}i, false)
               )
            end

            it 'handles this specific edge case i stumbled across' do
              expect(build('Ȋ/'))
                .to be_like PathList::Matchers::MatchIfDir.new(
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)Ȋ\z}i, false)
               )
            end
          end
        end

        # The slash / is used as the directory separator.
        # Separators may occur at the beginning, middle or end of the .gitignore search pattern.
        describe 'If there is a separator at the beginning or middle (or both) of the pattern' do
          describe 'then the pattern is relative to the directory level of the particular .gitignore file itself.' do
            # For example, a pattern doc/frotz/ matches doc/frotz directory, but not a/doc/frotz directory;
            # The pattern doc/frotz and /doc/frotz have the same effect in any .gitignore file.
            # In other words, a leading slash is not relevant if there is already a middle slash in the pattern.
            it 'includes files relative to the git dir with a middle slash' do
              expect(build('doc/frotz'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\Adoc/frotz\z}i, false)
            end

            it 'treats a double slash as matching nothing' do
              expect(build('doc//frotz'))
                .to be_like PathList::Matchers::Blank
            end
          end

          describe 'Otherwise the pattern may also match at any level below the .gitignore level.' do
            # frotz/ matches frotz and a/frotz that is a directory

            it 'includes files relative to anywhere with only an end slash' do
              expect(build('frotz/'))
                .to be_like PathList::Matchers::MatchIfDir.new(
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)frotz\z}i, false)
               )
            end

            it 'strips trailing space before deciding a rule is dir_only' do
              expect(build('frotz/ '))
                .to be_like PathList::Matchers::MatchIfDir.new(
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)frotz\z}i, false)
               )
            end
          end
        end

        describe 'An optional prefix "!" which negates the pattern' do
          describe 'any matching file excluded by a previous pattern will become included again.' do
            it 'includes previously excluded files' do
              expect(build('!foo'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\z}i, true)
            end
          end

          describe 'Put a backslash ("\") in front of the first "!" for patterns that begin with a literal "!"' do
            # for example, "\!important!.txt".'

            it 'matches files starting with a literal ! if its preceded by a backslash' do
              expect(build('\!important!.txt'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)!important!\.txt\z}i, false)
            end
          end
        end

        describe 'Otherwise, Git treats the pattern as a shell glob' do
          describe '"*" matches anything except "/"' do
            describe 'single level' do
              it "matches any number of characters at the beginning if there's a star" do
                expect(build('*our'))
                  .to be_like PathList::Matchers::PathRegexp.new(/our\z/i, false)
              end

              it "matches any number of characters at the beginning if there's a star followed by a slash" do
                expect(build('*/our'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A[^/]*/our\z}i, false)
              end

              it "doesn't match a slash" do
                expect(build('f*our'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)f[^/]*our\z}i, false)
              end

              it "matches any number of characters in the middle if there's a star" do
                expect(build('f*r'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)f[^/]*r\z}i, false)
              end

              it "matches any number of characters at the end if there's a star" do
                expect(build('few*'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)few[^/]*\z}i, false)
              end
            end

            describe 'multi level' do
              it 'matches a whole directory' do
                expect(build('a/*/c'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\Aa/[^/]*/c\z}i, false)
              end

              it 'matches an exact partial match at start' do
                expect(build('a/b*/c'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\Aa/b[^/]*/c\z}i, false)
              end

              it 'matches an exact partial match at end' do
                expect(build('a/*b/c'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\Aa/[^/]*b/c\z}i, false)
              end

              it 'matches multiple directories when sequential /*/' do
                expect(build('a/*/*'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\Aa/[^/]*/[^/]+\z}i, false)
              end

              it 'matches multiple directories when beginning sequential /*/' do
                expect(build('*/*/c'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A[^/]*/[^/]*/c\z}i, false)
              end

              it 'matches multiple directories when ending with /**/*' do
                expect(build('a/**/*'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\Aa/(?:.*/)?[^/]+\z}i, false)
              end

              it 'matches multiple directories when ending with **/*' do
                expect(build('a**/*'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\Aa(?:.*/)?[^/]+\z}i, false)
              end

              it 'matches multiple directories when beginning with **/*/' do
                expect(build('**/*/c'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{/c\z}i, false)
              end

              it 'matches multiple directories when beginning with **/*' do
                expect(build('**/*c'))
                  .to be_like PathList::Matchers::PathRegexp.new(/c\z/i, false)
              end
            end
          end

          describe '"?" matches any one character except "/"' do
            it "matches one character at the beginning if there's a ?" do
              expect(build('?our'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)[^/]our\z}i, false)
            end

            it "doesn't match a slash" do
              expect(build('fa?our'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)fa[^/]our\z}i, false)
            end

            it 'matches per ?' do
              expect(build('f??r'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)f[^/][^/]r\z}i, false)
            end

            it "matches a single character at the end if there's a ?" do
              expect(build('fou?'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)fou[^/]\z}i, false)
            end
          end

          describe '"[]" matches one character in a selected range' do
            it 'matches a single character in a character class' do
              expect(build('a[ab]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[ab]\z}i, false)
            end

            it 'matches a single character in a character class range' do
              expect(build('a[a-c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[a-c]\z}i, false)
            end

            it 'treats a backward character class range as only the first character of the range' do
              expect(build('a[d-a]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[d]\z}i, false)
            end

            it 'treats a negated backward character class range as only the first character of the range' do
              expect(build('a[^d-a]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^d]\z}i, false)
            end

            it 'treats a escaped backward character class range as only the first character of the range' do
              expect(build('a[\\]-\\[]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[\]]\z}i, false)
            end

            it 'treats a negated escaped backward character class range as only the first character of the range' do
              expect(build('a[^\\]-\\[]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^\]]\z}i, false)
            end

            it 'treats a escaped character class range as as a range' do
              expect(build('a[\\[-\\]]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[\[-\]]\z}i, false)
            end

            it 'treats a negated escaped character class range as a range' do
              expect(build('a[^\\[-\\]]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^\[-\]]\z}i, false)
            end

            it 'treats an unnecessarily escaped character class range as a range' do
              expect(build('a[\\a-\\c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[a-c]\z}i, false)
            end

            it 'treats a negated unnecessarily escaped character class range as a range' do
              expect(build('a[^\\a-\\c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^a-c]\z}i, false)
            end

            it 'treats a backward character class range with other options as only the first character of the range' do
              expect(build('a[d-ba]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[da]\z}i, false)
            end

            it 'treats a negated backward character class range with other chars as the first character of the range' do
              expect(build('a[^d-ba]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^da]\z}i, false)
            end

            it 'treats a backward char class range with other initial options as the first char of the range' do
              expect(build('a[ad-b]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[ad]\z}i, false)
            end

            it 'treats a negated backward char class range with other initial options as the first char of the range' do
              expect(build('a[^ad-b]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^ad]\z}i, false)
            end

            it 'treats a equal character class range as only the first character of the range' do
              expect(build('a[d-d]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[d]\z}i, false)
            end

            it 'treats a negated equal character class range as only the first character of the range' do
              expect(build('a[^d-d]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^d]\z}i, false)
            end

            it 'interprets a / after a character class range as not there' do
              expect(build('a[a-c/]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[a-c/]\z}i, false)
            end

            it 'interprets a / before a character class range as not there' do
              expect(build('a[/a-c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[/a-c]\z}i, false)
            end

            # TODO: confirm if that matches a slash character
            it 'interprets a / before the dash in a character class range as any character from / to c' do
              expect(build('a[+/-c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[\+/-c]\z}i, false)
            end

            it 'interprets a / after the dash in a character class range as any character from start to /' do
              expect(build('a["-/c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)["-/c]\z}i, false)
            end

            it 'interprets a slash then dash then character to be a character range' do
              expect(build('a[/-c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[/-c]\z}i, false)
            end

            it 'interprets a character then dash then slash to be a character range' do
              expect(build('a["-/]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)["-/]\z}i, false)
            end

            context 'without raising warnings' do
              # these edge cases raise warnings
              # they're edge-casey enough if you hit them you deserve warnings.
              before { allow(Warning).to receive(:warn) }

              it 'interprets dash dash character as a character range beginning with -' do
                expect(build('a[--c]'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[\--c]\z}i, false)
              end

              it 'interprets character dash dash as a character range ending with -' do
                expect(build('a["--]'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)["-\-]\z}i, false)
              end

              it 'interprets dash dash dash as a character range of only with -' do
                expect(build('a[---]'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[\-]\z}i, false)
              end

              it 'interprets character dash dash dash as a character range of only with " to - with literal -' do
                # for some reason this as a regexp literal triggers the warning raise
                # and building it with Regexp.new results in a regexp that is identical but not equal
                expect(build('a["---]'))
                  .to be_like PathList::Matchers::PathRegexp.new(
                    Regexp.new('(?:\\A|\/)a(?!\/)["-\\-\\-]\\z', 1), false
                 )
              end

              it 'interprets dash dash dash character as a character range of only - with literal c' do
                expect(build('a[---c]'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[\-c]\z}i, false)
              end

              it 'interprets character dash dash character as a character range ending with - and a literal c' do
                # this could just as easily be interpreted the other way around (" is the literal, --c is the range),
                # but ruby regex and git seem to treat this edge case the same
                expect(build('a["--c]'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)["-\-c]\z}i, false)
              end
            end

            it '^ is not' do
              expect(build('a[^a-c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^a-c]\z}i, false)
            end

            # this doesn't appear to be documented anywhere i just stumbled onto it
            it '! is also not' do
              expect(build('a[!a-c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^a-c]\z}i, false)
            end

            it '[^/] matches everything' do
              expect(build('a[^/]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^/]\z}i, false)
            end

            it '[^^] matches everything except literal ^' do
              expect(build('a[^^]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^\^]\z}i, false)
            end

            it '[^/a] matches everything except a' do
              expect(build('a[^/a]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^/a]\z}i, false)
            end

            it '[/^a] matches literal ^ and a' do
              expect(build('a[/^a]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[/\^a]\z}i, false)
            end

            it '[/^] matches literal ^' do
              expect(build('a[/^]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[/\^]\z}i, false)
            end

            it '[\\^] matches literal ^' do
              expect(build('a[\^]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[\^]\z}i, false)
            end

            it 'later ^ is literal' do
              expect(build('a[a-c^]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[a-c\^]\z}i, false)
            end

            it "doesn't match a slash even if you specify it last" do
              expect(build('b[i/]b'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)b(?!/)[i/]b\z}i, false)
            end

            it "doesn't match a slash even if you specify it alone" do
              expect(build('b[/]b'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)b(?!/)[/]b\z}i, false)
            end

            it 'empty class matches nothing' do
              expect(build('b[]b'))
                .to be_like PathList::Matchers::Blank
            end

            it "doesn't match a slash even if you specify it middle" do
              expect(build('b[i/a]b'))
                .to be_like PathList::Matchers::PathRegexp.new(
                  %r{(?:\A|/)b(?!/)[i/a]b\z}i, false
               )
            end

            it "doesn't match a slash even if you specify it start" do
              expect(build('b[/ai]b'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)b(?!/)[/ai]b\z}i, false)
            end

            it 'assumes an unfinished [ matches nothing' do
              expect(build('a['))
                .to be_like PathList::Matchers::Blank
            end

            it 'assumes an unfinished [ followed by \ matches nothing' do
              expect(build('a[\\'))
                .to be_like PathList::Matchers::Blank
            end

            it 'assumes an escaped [ is literal' do
              expect(build('a\\['))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a\[\z}i, false)
            end

            it 'assumes an escaped [ is literal inside a group' do
              expect(build('a[\\[]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[\[]\z}i, false)
            end

            it 'assumes an unfinished [ matches nothing when negated' do
              expect(build('!a['))
                .to be_like PathList::Matchers::Blank
            end

            it 'assumes an unfinished [bc matches nothing' do
              expect(build('a[bc'))
                .to be_like PathList::Matchers::Blank
            end
          end

          # See fnmatch(3) and the FNM_PATHNAME flag for a more detailed description
        end

        describe 'A leading slash matches the beginning of the pathname.' do
          # For example, "/*.c" matches "cat-file.c" but not "mozilla-sha1/sha1.c".
          it 'matches only at the beginning of everything' do
            expect(build('/*.c'))
              .to be_like PathList::Matchers::PathRegexp.new(%r{\A[^/]*\.c\z}i, false)
          end
        end

        describe 'Two consecutive asterisks ("**") in patterns matched against full pathname has special meaning:' do
          describe 'A leading "**" followed by a slash means match in all directories.' do
            # 'For example, "**/foo" matches file or directory "foo" anywhere, the same as pattern "foo".
            # "**/foo/bar" matches file or directory "bar" anywhere that is directly under directory "foo".'

            it 'matches files or directories in all directories' do
              expect(build('**/foo'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\z}i, false)
            end

            it 'matches nothing with double slash' do
              expect(build('**//foo'))
                .to be_like PathList::Matchers::Blank
            end

            it 'matches all directories when only **/ (interpreted as ** then the trailing / for dir only)' do
              expect(build('**/'))
                .to be_like PathList::Matchers::MatchIfDir.new(PathList::Matchers::Ignore)
            end

            it 'matches files or directories in all directories when repeated' do
              expect(build('**/**/foo'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\z}i, false)
            end

            it 'matches files or directories in all directories with **/*' do
              expect(build('**/*'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{[^/]\z}i, false)
            end

            it 'matches files or directories in all directories when also followed by a star before text' do
              expect(build('**/*foo'))
                .to be_like PathList::Matchers::PathRegexp.new(/foo\z/i, false)
            end

            it 'matches files or directories in all directories when also followed by a star within text' do
              expect(build('**/f*o'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)f[^/]*o\z}i, false)
            end

            it 'matches files or directories in all directories when also followed by a star after text' do
              expect(build('**/fo*'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)fo[^/]*\z}i, false)
            end

            it 'matches files or directories in all directories when three stars' do
              expect(build('***/foo'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\z}i, false)
            end
          end

          describe 'A trailing "/**" matches everything inside relative to the location of the .gitignore file.' do
            it 'matches files or directories inside the mentioned directory' do
              expect(build('abc/**'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\Aabc/}i, false)
            end

            it 'matches all directories inside the mentioned directory' do
              expect(build('abc/**/'))
                .to be_like PathList::Matchers::MatchIfDir.new(PathList::Matchers::PathRegexp.new(%r{\Aabc/}i, false))
            end

            it 'matches files or directories inside the mentioned directory when ***' do
              expect(build('abc/***'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\Aabc/}i, false)
            end
          end

          describe 'A slash followed by two consecutive asterisks then a slash matches zero or more directories.' do
            it 'matches multiple intermediate dirs' do
              expect(build('a/**/b'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\Aa/(?:.*/)?b\z}i, false)
            end

            it 'matches multiple intermediate dirs when ***' do
              expect(build('a/***/b'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\Aa/(?:.*/)?b\z}i, false)
            end
          end

          describe 'Other consecutive asterisks are considered regular asterisks' do
            describe 'and will match according to the previous rules' do
              context 'with two stars' do
                it 'matches any number of characters at the beginning' do
                  expect(build('**our'))
                    .to be_like PathList::Matchers::PathRegexp.new(/our\z/i, false)
                end

                it "doesn't match a slash" do
                  expect(build('f**our'))
                    .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)f[^/]*our\z}i, false)
                end

                it 'matches any number of characters in the middle' do
                  expect(build('f**r'))
                    .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)f[^/]*r\z}i, false)
                end

                it 'matches any number of characters at the end' do
                  expect(build('few**'))
                    .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)few}i, false)
                end

                # not sure if this is a bug but this is git behaviour
                it 'matches any number of directories including none, when following a character, and anchors' do
                  expect(build('f**/our'))
                    .to be_like PathList::Matchers::PathRegexp.new(%r{\Af(?:.*/)?our\z}i, false)
                end
              end
            end
          end
        end
      end
    end

    describe 'allow: false, root: "/a/path"' do
      let(:options) { { allow: false, root: "/a/path" } }

      describe 'from the gitignore documentation' do
        describe 'A blank line matches no files, so it can serve as a separator for readability.' do
          it { expect(build('')).to be_like PathList::Matchers::Blank }
          it { expect(build(' ')).to be_like PathList::Matchers::Blank }
          it { expect(build("\t")).to be_like PathList::Matchers::Blank }
        end

        describe 'The simple case' do
          it { expect(build('foo')).to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?foo\z}i, false) }
        end

        describe 'A line starting with # serves as a comment.' do
          it { expect(build('#foo')).to be_like PathList::Matchers::Blank }
          it { expect(build('# foo')).to be_like PathList::Matchers::Blank }
          it { expect(build('#')).to be_like PathList::Matchers::Blank }

          it 'must be the first character' do
            expect(build(' #foo'))
              .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?\ \#foo\z}i, false)
          end

          describe 'Put a backslash ("\") in front of the first hash for patterns that begin with a hash' do
            it do
              expect(build('\\#foo'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?\#foo\z}i, false)
            end
          end
        end

        describe 'literal backslashes in filenames' do
          it 'matches an escaped backslash at the end of the pattern' do
            expect(build('foo\\\\'))
              .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?foo\\\z}i, false)
          end

          it 'never matches a literal backslash at the end of the pattern' do
            expect(build('foo\\'))
              .to be_like PathList::Matchers::Blank
          end

          it 'matches an escaped backslash at the start of the pattern' do
            expect(build('\\\\foo'))
              .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?\\foo\z}i, false)
          end

          it 'matches a literal escaped f at the start of the pattern' do
            expect(build('\\foo'))
              .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?foo\z}i, false)
          end
        end

        describe 'Trailing spaces are ignored unless they are quoted with backslash ("\")' do
          it 'ignores trailing spaces in the gitignore file' do
            expect(build('foo  '))
              .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?foo\z}i, false)
          end

          it "doesn't ignore trailing spaces if there's a backslash" do
            expect(build('foo \\ '))
              .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?foo\ \ \z}i, false)
          end

          it 'considers trailing backslashes to never be matched' do
            expect(build('foo\\'))
              .to be_like PathList::Matchers::Blank
          end

          it "doesn't ignore trailing spaces if there's a backslash before every space" do
            expect(build('foo\\ \\ '))
              .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?foo\ \ \z}i, false)
          end

          it "doesn't ignore just that trailing spaces if there's a backslash before the non last space" do
            expect(build('foo\\  '))
              .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?foo\ \z}i, false)
          end
        end

        describe 'If the pattern ends with a slash, it is removed for the purpose of the following description' do
          describe 'but it would only find a match with a directory' do
            # In other words, foo/ will match a directory foo and paths underneath it,
            # but will not match a regular file or a symbolic link foo
            # (this is consistent with the way how pathspec works in general in Git).

            it 'ignores directories but not files or symbolic links that match patterns ending with /' do
              expect(build('foo/'))
                .to be_like PathList::Matchers::MatchIfDir.new(
                  PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?foo\z}i, false)
               )
            end

            it 'handles this specific edge case i stumbled across' do
              expect(build('Ȋ/'))
                .to be_like PathList::Matchers::MatchIfDir.new(
                  PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?Ȋ\z}i, false)
               )
            end
          end
        end

        # The slash / is used as the directory separator.
        # Separators may occur at the beginning, middle or end of the .gitignore search pattern.
        describe 'If there is a separator at the beginning or middle (or both) of the pattern' do
          describe 'then the pattern is relative to the directory level of the particular .gitignore file itself.' do
            # For example, a pattern doc/frotz/ matches doc/frotz directory, but not a/doc/frotz directory;
            # The pattern doc/frotz and /doc/frotz have the same effect in any .gitignore file.
            # In other words, a leading slash is not relevant if there is already a middle slash in the pattern.
            it 'includes files relative to the git dir with a middle slash' do
              expect(build('doc/frotz'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/doc/frotz\z}i, false)
            end

            it 'treats a double slash as matching nothing' do
              expect(build('doc//frotz'))
                .to be_like PathList::Matchers::Blank
            end
          end

          describe 'Otherwise the pattern may also match at any level below the .gitignore level.' do
            # frotz/ matches frotz and a/frotz that is a directory

            it 'includes files relative to anywhere with only an end slash' do
              expect(build('frotz/'))
                .to be_like PathList::Matchers::MatchIfDir.new(
                  PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?frotz\z}i, false)
               )
            end

            it 'strips trailing space before deciding a rule is dir_only' do
              expect(build('frotz/ '))
                .to be_like PathList::Matchers::MatchIfDir.new(
                  PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?frotz\z}i, false)
               )
            end
          end
        end

        describe 'An optional prefix "!" which negates the pattern' do
          describe 'any matching file excluded by a previous pattern will become included again.' do
            it 'includes previously excluded files' do
              expect(build('!foo'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?foo\z}i, true)
            end
          end

          describe 'Put a backslash ("\") in front of the first "!" for patterns that begin with a literal "!"' do
            # for example, "\!important!.txt".'

            it 'matches files starting with a literal ! if its preceded by a backslash' do
              expect(build('\!important!.txt'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?!important!\.txt\z}i, false)
            end
          end
        end

        describe 'Otherwise, Git treats the pattern as a shell glob' do
          describe '"*" matches anything except "/"' do
            describe 'single level' do
              it "matches any number of characters at the beginning if there's a star" do
                expect(build('*our'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/.*our\z}i, false)
              end

              it "matches any number of characters at the beginning if there's a star followed by a slash" do
                expect(build('*/our'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/[^/]*/our\z}i, false)
              end

              it "doesn't match a slash" do
                expect(build('f*our'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?f[^/]*our\z}i, false)
              end

              it "matches any number of characters in the middle if there's a star" do
                expect(build('f*r'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?f[^/]*r\z}i, false)
              end

              it "matches any number of characters at the end if there's a star" do
                expect(build('few*'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?few[^/]*\z}i, false)
              end
            end

            describe 'multi level' do
              it 'matches a whole directory' do
                expect(build('a/*/c'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a/[^/]*/c\z}i, false)
              end

              it 'matches an exact partial match at start' do
                expect(build('a/b*/c'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a/b[^/]*/c\z}i, false)
              end

              it 'matches an exact partial match at end' do
                expect(build('a/*b/c'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a/[^/]*b/c\z}i, false)
              end

              it 'matches multiple directories when sequential /*/' do
                expect(build('a/*/*'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a/[^/]*/[^/]*\z}i, false)
              end

              it 'matches multiple directories when beginning sequential /*/' do
                expect(build('*/*/c'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/[^/]*/[^/]*/c\z}i, false)
              end

              it 'matches multiple directories when ending with /**/*' do
                expect(build('a/**/*'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a/}i, false)
              end

              it 'matches multiple directories when ending with **/*' do
                expect(build('a**/*'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a}i, false)
              end

              it 'matches multiple directories when beginning with **/*/' do
                expect(build('**/*/c'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/.*/c\z}i, false)
              end

              it 'matches multiple directories when beginning with **/*' do
                expect(build('**/*c'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/.*c\z}i, false)
              end
            end
          end

          describe '"?" matches any one character except "/"' do
            it "matches one character at the beginning if there's a ?" do
              expect(build('?our'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?[^/]our\z}i, false)
            end

            it "doesn't match a slash" do
              expect(build('fa?our'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?fa[^/]our\z}i, false)
            end

            it 'matches per ?' do
              expect(build('f??r'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?f[^/][^/]r\z}i, false)
            end

            it "matches a single character at the end if there's a ?" do
              expect(build('fou?'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?fou[^/]\z}i, false)
            end
          end

          describe '"[]" matches one character in a selected range' do
            it 'matches a single character in a character class' do
              expect(build('a[ab]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[ab]\z}i, false)
            end

            it 'matches a single character in a character class range' do
              expect(build('a[a-c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[a-c]\z}i, false)
            end

            it 'treats a backward character class range as only the first character of the range' do
              expect(build('a[d-a]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[d]\z}i, false)
            end

            it 'treats a negated backward character class range as only the first character of the range' do
              expect(build('a[^d-a]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[^d]\z}i, false)
            end

            it 'treats a escaped backward character class range as only the first character of the range' do
              expect(build('a[\\]-\\[]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[\]]\z}i, false)
            end

            it 'treats a negated escaped backward character class range as only the first character of the range' do
              expect(build('a[^\\]-\\[]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[^\]]\z}i, false)
            end

            it 'treats a escaped character class range as as a range' do
              expect(build('a[\\[-\\]]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[\[-\]]\z}i, false)
            end

            it 'treats a negated escaped character class range as a range' do
              expect(build('a[^\\[-\\]]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[^\[-\]]\z}i, false)
            end

            it 'treats an unnecessarily escaped character class range as a range' do
              expect(build('a[\\a-\\c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[a-c]\z}i, false)
            end

            it 'treats a negated unnecessarily escaped character class range as a range' do
              expect(build('a[^\\a-\\c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[^a-c]\z}i, false)
            end

            it 'treats a backward character class range with other options as only the first character of the range' do
              expect(build('a[d-ba]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[da]\z}i, false)
            end

            it 'treats a negated backward character class range with other chars as the first character of the range' do
              expect(build('a[^d-ba]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[^da]\z}i, false)
            end

            it 'treats a backward char class range with other initial options as the first char of the range' do
              expect(build('a[ad-b]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[ad]\z}i, false)
            end

            it 'treats a negated backward char class range with other initial options as the first char of the range' do
              expect(build('a[^ad-b]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[^ad]\z}i, false)
            end

            it 'treats a equal character class range as only the first character of the range' do
              expect(build('a[d-d]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[d]\z}i, false)
            end

            it 'treats a negated equal character class range as only the first character of the range' do
              expect(build('a[^d-d]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[^d]\z}i, false)
            end

            it 'interprets a / after a character class range as not there' do
              expect(build('a[a-c/]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[a-c/]\z}i, false)
            end

            it 'interprets a / before a character class range as not there' do
              expect(build('a[/a-c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[/a-c]\z}i, false)
            end

            # TODO: confirm if that matches a slash character
            it 'interprets a / before the dash in a character class range as any character from / to c' do
              expect(build('a[+/-c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[\+/-c]\z}i, false)
            end

            it 'interprets a / after the dash in a character class range as any character from start to /' do
              expect(build('a["-/c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)["-/c]\z}i, false)
            end

            it 'interprets a slash then dash then character to be a character range' do
              expect(build('a[/-c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[/-c]\z}i, false)
            end

            it 'interprets a character then dash then slash to be a character range' do
              expect(build('a["-/]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)["-/]\z}i, false)
            end

            context 'without raising warnings' do
              # these edge cases raise warnings
              # they're edge-casey enough if you hit them you deserve warnings.
              before { allow(Warning).to receive(:warn) }

              it 'interprets dash dash character as a character range beginning with -' do
                expect(build('a[--c]'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[\--c]\z}i, false)
              end

              it 'interprets character dash dash as a character range ending with -' do
                expect(build('a["--]'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)["-\-]\z}i, false)
              end

              it 'interprets dash dash dash as a character range of only with -' do
                expect(build('a[---]'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[\-]\z}i, false)
              end

              it 'interprets character dash dash dash as a character range of only with " to - with literal -' do
                # for some reason this as a regexp literal triggers the warning raise
                # and building it with Regexp.new results in a regexp that is identical but not equal
                expect(build('a["---]'))
                  .to be_like PathList::Matchers::PathRegexp.new(
                    Regexp.new('\\A/a/path/(?:.*/)?a(?!\/)["-\\-\\-]\\z', 1), false
                 )
              end

              it 'interprets dash dash dash character as a character range of only - with literal c' do
                expect(build('a[---c]'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[\-c]\z}i, false)
              end

              it 'interprets character dash dash character as a character range ending with - and a literal c' do
                # this could just as easily be interpreted the other way around (" is the literal, --c is the range),
                # but ruby regex and git seem to treat this edge case the same
                expect(build('a["--c]'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)["-\-c]\z}i, false)
              end
            end

            it '^ is not' do
              expect(build('a[^a-c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[^a-c]\z}i, false)
            end

            # this doesn't appear to be documented anywhere i just stumbled onto it
            it '! is also not' do
              expect(build('a[!a-c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[^a-c]\z}i, false)
            end

            it '[^/] matches everything' do
              expect(build('a[^/]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[^/]\z}i, false)
            end

            it '[^^] matches everything except literal ^' do
              expect(build('a[^^]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[^\^]\z}i, false)
            end

            it '[^/a] matches everything except a' do
              expect(build('a[^/a]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[^/a]\z}i, false)
            end

            it '[/^a] matches literal ^ and a' do
              expect(build('a[/^a]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[/\^a]\z}i, false)
            end

            it '[/^] matches literal ^' do
              expect(build('a[/^]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[/\^]\z}i, false)
            end

            it '[\\^] matches literal ^' do
              expect(build('a[\^]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[\^]\z}i, false)
            end

            it 'later ^ is literal' do
              expect(build('a[a-c^]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[a-c\^]\z}i, false)
            end

            it "doesn't match a slash even if you specify it last" do
              expect(build('b[i/]b'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?b(?!/)[i/]b\z}i, false)
            end

            it "doesn't match a slash even if you specify it alone" do
              expect(build('b[/]b'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?b(?!/)[/]b\z}i, false)
            end

            it 'empty class matches nothing' do
              expect(build('b[]b'))
                .to be_like PathList::Matchers::Blank
            end

            it "doesn't match a slash even if you specify it middle" do
              expect(build('b[i/a]b'))
                .to be_like PathList::Matchers::PathRegexp.new(
                  %r{\A/a/path/(?:.*/)?b(?!/)[i/a]b\z}i, false
               )
            end

            it "doesn't match a slash even if you specify it start" do
              expect(build('b[/ai]b'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?b(?!/)[/ai]b\z}i, false)
            end

            it 'assumes an unfinished [ matches nothing' do
              expect(build('a['))
                .to be_like PathList::Matchers::Blank
            end

            it 'assumes an unfinished [ followed by \ matches nothing' do
              expect(build('a[\\'))
                .to be_like PathList::Matchers::Blank
            end

            it 'assumes an escaped [ is literal' do
              expect(build('a\\['))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?a\[\z}i, false)
            end

            it 'assumes an escaped [ is literal inside a group' do
              expect(build('a[\\[]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?a(?!/)[\[]\z}i, false)
            end

            it 'assumes an unfinished [ matches nothing when negated' do
              expect(build('!a['))
                .to be_like PathList::Matchers::Blank
            end

            it 'assumes an unfinished [bc matches nothing' do
              expect(build('a[bc'))
                .to be_like PathList::Matchers::Blank
            end
          end

          # See fnmatch(3) and the FNM_PATHNAME flag for a more detailed description
        end

        describe 'A leading slash matches the beginning of the pathname.' do
          # For example, "/*.c" matches "cat-file.c" but not "mozilla-sha1/sha1.c".
          it 'matches only at the beginning of everything' do
            expect(build('/*.c'))
              .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/[^/]*\.c\z}i, false)
          end
        end

        describe 'Two consecutive asterisks ("**") in patterns matched against full pathname has special meaning:' do
          describe 'A leading "**" followed by a slash means match in all directories.' do
            # 'For example, "**/foo" matches file or directory "foo" anywhere, the same as pattern "foo".
            # "**/foo/bar" matches file or directory "bar" anywhere that is directly under directory "foo".'

            it 'matches files or directories in all directories' do
              expect(build('**/foo'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?foo\z}i, false)
            end

            it 'matches nothing with double slash' do
              expect(build('**//foo'))
                .to be_like PathList::Matchers::Blank
            end

            it 'matches all directories when only **/ (interpreted as ** then the trailing / for dir only)' do
              expect(build('**/'))
                .to be_like PathList::Matchers::MatchIfDir.new(
                  PathList::Matchers::PathRegexp.new(%r{\A/a/path/}i, false))
            end

            it 'matches files or directories in all directories when repeated' do
              expect(build('**/**/foo'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?foo\z}i, false)
            end

            it 'matches files or directories in all directories with **/*' do
              expect(build('**/*'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/}i, false)
            end

            it 'matches files or directories in all directories when also followed by a star before text' do
              expect(build('**/*foo'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/.*foo\z}i, false)
            end

            it 'matches files or directories in all directories when also followed by a star within text' do
              expect(build('**/f*o'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?f[^/]*o\z}i, false)
            end

            it 'matches files or directories in all directories when also followed by a star after text' do
              expect(build('**/fo*'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?fo[^/]*\z}i, false)
            end

            it 'matches files or directories in all directories when three stars' do
              expect(build('***/foo'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?foo\z}i, false)
            end
          end

          describe 'A trailing "/**" matches everything inside relative to the location of the .gitignore file.' do
            it 'matches files or directories inside the mentioned directory' do
              expect(build('abc/**'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/abc/}i, false)
            end

            it 'matches all directories inside the mentioned directory' do
              expect(build('abc/**/'))
                .to be_like PathList::Matchers::MatchIfDir.new(PathList::Matchers::PathRegexp.new(%r{\A/a/path/abc/}i,
                                                                                                  false))
            end

            it 'matches files or directories inside the mentioned directory when ***' do
              expect(build('abc/***'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/abc/}i, false)
            end
          end

          describe 'A slash followed by two consecutive asterisks then a slash matches zero or more directories.' do
            it 'matches multiple intermediate dirs' do
              expect(build('a/**/b'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a/(?:.*/)?b\z}i, false)
            end

            it 'matches multiple intermediate dirs when ***' do
              expect(build('a/***/b'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a/(?:.*/)?b\z}i, false)
            end
          end

          describe 'Other consecutive asterisks are considered regular asterisks' do
            describe 'and will match according to the previous rules' do
              context 'with two stars' do
                it 'matches any number of characters at the beginning' do
                  expect(build('**our'))
                    .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/.*our\z}i, false)
                end

                it "doesn't match a slash" do
                  expect(build('f**our'))
                    .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?f[^/]*our\z}i, false)
                end

                it 'matches any number of characters in the middle' do
                  expect(build('f**r'))
                    .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?f[^/]*r\z}i, false)
                end

                it 'matches any number of characters at the end' do
                  expect(build('few**'))
                    .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*/)?few[^/]*\z}i, false)
                end

                # not sure if this is a bug but this is git behaviour
                it 'matches any number of directories including none, when following a character, and anchors' do
                  expect(build('f**/our'))
                    .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/f(?:.*/)?our\z}i, false)
                end
              end
            end
          end
        end
      end
    end

    describe 'allow: false, root: "/a/path", expand_path: true' do
      let(:options) { { allow: false, root: "/a/path", expand_path: true } }

      describe 'from the gitignore documentation' do
        describe 'A blank line matches no files, so it can serve as a separator for readability.' do
          it { expect(build('')).to be_like PathList::Matchers::Blank }
          it { expect(build(' ')).to be_like PathList::Matchers::Blank }
          it { expect(build("\t")).to be_like PathList::Matchers::Blank }
        end

        describe 'The simple case' do
          it { expect(build('foo')).to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/foo\z}i, false) }
        end

        describe 'leading ./ means current directory based on the root' do
          it { expect(build('./foo')).to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/foo\z}i, false) }
        end

        describe 'A line starting with # serves as a comment.' do
          it { expect(build('#foo')).to be_like PathList::Matchers::Blank }
          it { expect(build('# foo')).to be_like PathList::Matchers::Blank }
          it { expect(build('#')).to be_like PathList::Matchers::Blank }

          it 'must be the first character' do
            expect(build(' #foo'))
              .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/\ \#foo\z}i, false)
          end

          describe 'Put a backslash ("\") in front of the first hash for patterns that begin with a hash' do
            it do
              expect(build('\\#foo'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/\#foo\z}i, false)
            end
          end
        end

        describe 'literal backslashes in filenames' do
          it 'matches an escaped backslash at the end of the pattern' do
            expect(build('foo\\\\'))
              .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/foo\\\z}i, false)
          end

          it 'never matches a literal backslash at the end of the pattern' do
            expect(build('foo\\'))
              .to be_like PathList::Matchers::Blank
          end

          it 'matches an escaped backslash at the start of the pattern' do
            expect(build('\\\\foo'))
              .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/\\foo\z}i, false)
          end

          it 'matches a literal escaped f at the start of the pattern' do
            expect(build('\\foo'))
              .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/foo\z}i, false)
          end
        end

        describe 'Trailing spaces are ignored unless they are quoted with backslash ("\")' do
          it 'ignores trailing spaces in the gitignore file' do
            expect(build('foo  '))
              .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/foo\z}i, false)
          end

          it "doesn't ignore trailing spaces if there's a backslash" do
            expect(build('foo \\ '))
              .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/foo\ \ \z}i, false)
          end

          it 'considers trailing backslashes to never be matched' do
            expect(build('foo\\'))
              .to be_like PathList::Matchers::Blank
          end

          it "doesn't ignore trailing spaces if there's a backslash before every space" do
            expect(build('foo\\ \\ '))
              .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/foo\ \ \z}i, false)
          end

          it "doesn't ignore just that trailing spaces if there's a backslash before the non last space" do
            expect(build('foo\\  '))
              .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/foo\ \z}i, false)
          end
        end

        describe 'If the pattern ends with a slash, it is removed for the purpose of the following description' do
          describe 'but it would only find a match with a directory' do
            # In other words, foo/ will match a directory foo and paths underneath it,
            # but will not match a regular file or a symbolic link foo
            # (this is consistent with the way how pathspec works in general in Git).

            it 'ignores directories but not files or symbolic links that match patterns ending with /' do
              expect(build('foo/'))
                .to be_like PathList::Matchers::MatchIfDir.new(
                  PathList::Matchers::PathRegexp.new(%r{\A/a/path/foo\z}i, false)
               )
            end

            it 'handles this specific edge case i stumbled across' do
              expect(build('Ȋ/'))
                .to be_like PathList::Matchers::MatchIfDir.new(
                  PathList::Matchers::PathRegexp.new(%r{\A/a/path/Ȋ\z}i, false)
               )
            end
          end
        end

        # The slash / is used as the directory separator.
        # Separators may occur at the beginning, middle or end of the .gitignore search pattern.
        describe 'If there is a separator at the beginning or middle (or both) of the pattern' do
          describe 'then the pattern is relative to the directory level of the particular .gitignore file itself.' do
            # For example, a pattern doc/frotz/ matches doc/frotz directory, but not a/doc/frotz directory;
            # The pattern doc/frotz and /doc/frotz have the same effect in any .gitignore file.
            # In other words, a leading slash is not relevant if there is already a middle slash in the pattern.
            it 'includes files relative to the git dir with a middle slash' do
              expect(build('doc/frotz'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/doc/frotz\z}i, false)
            end

            it 'treats a double slash as matching nothing' do
              expect(build('doc//frotz'))
                .to be_like PathList::Matchers::Blank
            end
          end

          describe 'Otherwise the pattern may also match at any level below the .gitignore level.' do
            # frotz/ matches frotz and a/frotz that is a directory

            it 'includes files relative to anywhere with only an end slash' do
              expect(build('frotz/'))
                .to be_like PathList::Matchers::MatchIfDir.new(
                  PathList::Matchers::PathRegexp.new(%r{\A/a/path/frotz\z}i, false)
               )
            end

            it 'strips trailing space before deciding a rule is dir_only' do
              expect(build('frotz/ '))
                .to be_like PathList::Matchers::MatchIfDir.new(
                  PathList::Matchers::PathRegexp.new(%r{\A/a/path/frotz\z}i, false)
               )
            end
          end
        end

        describe 'An optional prefix "!" which negates the pattern' do
          describe 'any matching file excluded by a previous pattern will become included again.' do
            it 'includes previously excluded files' do
              expect(build('!foo'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/foo\z}i, true)
            end
          end

          describe 'Put a backslash ("\") in front of the first "!" for patterns that begin with a literal "!"' do
            # for example, "\!important!.txt".'

            it 'matches files starting with a literal ! if its preceded by a backslash' do
              expect(build('\!important!.txt'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/!important!\.txt\z}i, false)
            end
          end
        end

        describe 'Otherwise, Git treats the pattern as a shell glob' do
          describe '"*" matches anything except "/"' do
            describe 'single level' do
              it "matches any number of characters at the beginning if there's a star" do
                expect(build('*our'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/.*our\z}i, false)
              end

              it "matches any number of characters at the beginning if there's a star followed by a slash" do
                expect(build('*/our'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/[^/]*/our\z}i, false)
              end

              it "doesn't match a slash" do
                expect(build('f*our'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/f[^/]*our\z}i, false)
              end

              it "matches any number of characters in the middle if there's a star" do
                expect(build('f*r'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/f[^/]*r\z}i, false)
              end

              it "matches any number of characters at the end if there's a star" do
                expect(build('few*'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/few[^/]*\z}i, false)
              end
            end

            describe 'multi level' do
              it 'matches a whole directory' do
                expect(build('a/*/c'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a/[^/]*/c\z}i, false)
              end

              it 'matches an exact partial match at start' do
                expect(build('a/b*/c'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a/b[^/]*/c\z}i, false)
              end

              it 'matches an exact partial match at end' do
                expect(build('a/*b/c'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a/[^/]*b/c\z}i, false)
              end

              it 'matches multiple directories when sequential /*/' do
                expect(build('a/*/*'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a/[^/]*/[^/]*\z}i, false)
              end

              it 'matches multiple directories when beginning sequential /*/' do
                expect(build('*/*/c'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/[^/]*/[^/]*/c\z}i, false)
              end

              it 'matches multiple directories when ending with /**/*' do
                expect(build('a/**/*'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a/}i, false)
              end

              it 'matches multiple directories when ending with **/*' do
                expect(build('a**/*'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a}i, false)
              end

              it 'matches multiple directories when beginning with **/*/' do
                expect(build('**/*/c'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/.*/c\z}i, false)
              end

              it 'matches multiple directories when beginning with **/*' do
                expect(build('**/*c'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/.*c\z}i, false)
              end
            end
          end

          describe '"?" matches any one character except "/"' do
            it "matches one character at the beginning if there's a ?" do
              expect(build('?our'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/[^/]our\z}i, false)
            end

            it "doesn't match a slash" do
              expect(build('fa?our'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/fa[^/]our\z}i, false)
            end

            it 'matches per ?' do
              expect(build('f??r'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/f[^/][^/]r\z}i, false)
            end

            it "matches a single character at the end if there's a ?" do
              expect(build('fou?'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/fou[^/]\z}i, false)
            end
          end

          describe '"[]" matches one character in a selected range' do
            it 'matches a single character in a character class' do
              expect(build('a[ab]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a(?!/)[ab]\z}i, false)
            end

            it 'matches a single character in a character class range' do
              expect(build('a[a-c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a(?!/)[a-c]\z}i, false)
            end

            it 'treats a backward character class range as only the first character of the range' do
              expect(build('a[d-a]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a(?!/)[d]\z}i, false)
            end

            it 'treats a negated backward character class range as only the first character of the range' do
              expect(build('a[^d-a]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a(?!/)[^d]\z}i, false)
            end

            it 'treats a escaped backward character class range as only the first character of the range' do
              expect(build('a[\\]-\\[]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a(?!/)[\]]\z}i, false)
            end

            it 'treats a negated escaped backward character class range as only the first character of the range' do
              expect(build('a[^\\]-\\[]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a(?!/)[^\]]\z}i, false)
            end

            it 'treats a escaped character class range as as a range' do
              expect(build('a[\\[-\\]]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a(?!/)[\[-\]]\z}i, false)
            end

            it 'treats a negated escaped character class range as a range' do
              expect(build('a[^\\[-\\]]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a(?!/)[^\[-\]]\z}i, false)
            end

            it 'treats an unnecessarily escaped character class range as a range' do
              expect(build('a[\\a-\\c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a(?!/)[a-c]\z}i, false)
            end

            it 'treats a negated unnecessarily escaped character class range as a range' do
              expect(build('a[^\\a-\\c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a(?!/)[^a-c]\z}i, false)
            end

            it 'treats a backward character class range with other options as only the first character of the range' do
              expect(build('a[d-ba]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a(?!/)[da]\z}i, false)
            end

            it 'treats a negated backward character class range with other chars as the first character of the range' do
              expect(build('a[^d-ba]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a(?!/)[^da]\z}i, false)
            end

            it 'treats a backward char class range with other initial options as the first char of the range' do
              expect(build('a[ad-b]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a(?!/)[ad]\z}i, false)
            end

            it 'treats a negated backward char class range with other initial options as the first char of the range' do
              expect(build('a[^ad-b]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a(?!/)[^ad]\z}i, false)
            end

            it 'treats a equal character class range as only the first character of the range' do
              expect(build('a[d-d]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a(?!/)[d]\z}i, false)
            end

            it 'treats a negated equal character class range as only the first character of the range' do
              expect(build('a[^d-d]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a(?!/)[^d]\z}i, false)
            end

            it 'interprets a / after a character class range as not there' do
              expect(build('a[a-c/]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a(?!/)[a-c/]\z}i, false)
            end

            it 'interprets a / before a character class range as not there' do
              expect(build('a[/a-c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a(?!/)[/a-c]\z}i, false)
            end

            # TODO: confirm if that matches a slash character
            it 'interprets a / before the dash in a character class range as any character from / to c' do
              expect(build('a[+/-c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a(?!/)[\+/-c]\z}i, false)
            end

            it 'interprets a / after the dash in a character class range as any character from start to /' do
              expect(build('a["-/c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a(?!/)["-/c]\z}i, false)
            end

            it 'interprets a slash then dash then character to be a character range' do
              expect(build('a[/-c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a(?!/)[/-c]\z}i, false)
            end

            it 'interprets a character then dash then slash to be a character range' do
              expect(build('a["-/]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a(?!/)["-/]\z}i, false)
            end

            context 'without raising warnings' do
              # these edge cases raise warnings
              # they're edge-casey enough if you hit them you deserve warnings.
              before { allow(Warning).to receive(:warn) }

              it 'interprets dash dash character as a character range beginning with -' do
                expect(build('a[--c]'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a(?!/)[\--c]\z}i, false)
              end

              it 'interprets character dash dash as a character range ending with -' do
                expect(build('a["--]'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a(?!/)["-\-]\z}i, false)
              end

              it 'interprets dash dash dash as a character range of only with -' do
                expect(build('a[---]'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a(?!/)[\-]\z}i, false)
              end

              it 'interprets character dash dash dash as a character range of only with " to - with literal -' do
                # for some reason this as a regexp literal triggers the warning raise
                # and building it with Regexp.new results in a regexp that is identical but not equal
                expect(build('a["---]'))
                  .to be_like PathList::Matchers::PathRegexp.new(
                    Regexp.new('\\A/a/path/a(?!\/)["-\\-\\-]\\z', 1), false
                 )
              end

              it 'interprets dash dash dash character as a character range of only - with literal c' do
                expect(build('a[---c]'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a(?!/)[\-c]\z}i, false)
              end

              it 'interprets character dash dash character as a character range ending with - and a literal c' do
                # this could just as easily be interpreted the other way around (" is the literal, --c is the range),
                # but ruby regex and git seem to treat this edge case the same
                expect(build('a["--c]'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a(?!/)["-\-c]\z}i, false)
              end
            end

            it '^ is not' do
              expect(build('a[^a-c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a(?!/)[^a-c]\z}i, false)
            end

            # this doesn't appear to be documented anywhere i just stumbled onto it
            it '! is also not' do
              expect(build('a[!a-c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a(?!/)[^a-c]\z}i, false)
            end

            it '[^/] matches everything' do
              expect(build('a[^/]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a(?!/)[^/]\z}i, false)
            end

            it '[^^] matches everything except literal ^' do
              expect(build('a[^^]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a(?!/)[^\^]\z}i, false)
            end

            it '[^/a] matches everything except a' do
              expect(build('a[^/a]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a(?!/)[^/a]\z}i, false)
            end

            it '[/^a] matches literal ^ and a' do
              expect(build('a[/^a]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a(?!/)[/\^a]\z}i, false)
            end

            it '[/^] matches literal ^' do
              expect(build('a[/^]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a(?!/)[/\^]\z}i, false)
            end

            it '[\\^] matches literal ^' do
              expect(build('a[\^]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a(?!/)[\^]\z}i, false)
            end

            it 'later ^ is literal' do
              expect(build('a[a-c^]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a(?!/)[a-c\^]\z}i, false)
            end

            it "doesn't match a slash even if you specify it last" do
              expect(build('b[i/]b'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/b(?!/)[i/]b\z}i, false)
            end

            it "doesn't match a slash even if you specify it alone" do
              expect(build('b[/]b'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/b(?!/)[/]b\z}i, false)
            end

            it 'empty class matches nothing' do
              expect(build('b[]b'))
                .to be_like PathList::Matchers::Blank
            end

            it "doesn't match a slash even if you specify it middle" do
              expect(build('b[i/a]b'))
                .to be_like PathList::Matchers::PathRegexp.new(
                  %r{\A/a/path/b(?!/)[i/a]b\z}i, false
               )
            end

            it "doesn't match a slash even if you specify it start" do
              expect(build('b[/ai]b'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/b(?!/)[/ai]b\z}i, false)
            end

            it 'assumes an unfinished [ matches nothing' do
              expect(build('a['))
                .to be_like PathList::Matchers::Blank
            end

            it 'assumes an unfinished [ followed by \ matches nothing' do
              expect(build('a[\\'))
                .to be_like PathList::Matchers::Blank
            end

            it 'assumes an escaped [ is literal' do
              expect(build('a\\['))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a\[\z}i, false)
            end

            it 'assumes an escaped [ is literal inside a group' do
              expect(build('a[\\[]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a(?!/)[\[]\z}i, false)
            end

            it 'assumes an unfinished [ matches nothing when negated' do
              expect(build('!a['))
                .to be_like PathList::Matchers::Blank
            end

            it 'assumes an unfinished [bc matches nothing' do
              expect(build('a[bc'))
                .to be_like PathList::Matchers::Blank
            end
          end

          # See fnmatch(3) and the FNM_PATHNAME flag for a more detailed description
        end

        describe 'A leading slash matches the root of the filesystem.' do
          # For example, "/*.c" matches "cat-file.c" but not "mozilla-sha1/sha1.c".
          it 'matches only at the beginning of everything' do
            expect(build('/*.c'))
              .to be_like PathList::Matchers::PathRegexp.new(%r{\A/[^/]*\.c\z}i, false)
          end
        end

        describe 'Two consecutive asterisks ("**") in patterns matched against full pathname has special meaning:' do
          describe 'A leading "**" followed by a slash means match in all directories.' do
            # 'For example, "**/foo" matches file or directory "foo" anywhere, the same as pattern "foo".
            # "**/foo/bar" matches file or directory "bar" anywhere that is directly under directory "foo".'

            it 'matches files or directories in all directories' do
              expect(build('**/foo'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*\/)?foo\z}i, false)
            end

            it 'matches nothing with double slash' do
              expect(build('**//foo'))
                .to be_like PathList::Matchers::Blank
            end

            it 'matches all directories when only **/ (interpreted as ** then the trailing / for dir only)' do
              expect(build('**/'))
                .to be_like PathList::Matchers::MatchIfDir.new(PathList::Matchers::PathRegexp.new(%r{\A/a/path/}i,
                                                                                                  false))
            end

            it 'matches files or directories in all directories when repeated' do
              expect(build('**/**/foo'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*\/)?foo\z}i, false)
            end

            it 'matches files or directories in all directories with **/*' do
              expect(build('**/*'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/}i, false)
            end

            it 'matches files or directories in all directories when also followed by a star before text' do
              expect(build('**/*foo'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/.*foo\z}i, false)
            end

            it 'matches files or directories in all directories when also followed by a star within text' do
              expect(build('**/f*o'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*\/)?f[^/]*o\z}i, false)
            end

            it 'matches files or directories in all directories when also followed by a star after text' do
              expect(build('**/fo*'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*\/)?fo[^/]*\z}i, false)
            end

            it 'matches files or directories in all directories when three stars' do
              expect(build('***/foo'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/(?:.*\/)?foo\z}i, false)
            end
          end

          describe 'A trailing "/**" matches everything inside relative to the location of the .gitignore file.' do
            it 'matches files or directories inside the mentioned directory' do
              expect(build('abc/**'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/abc/}i, false)
            end

            it 'matches all directories inside the mentioned directory' do
              expect(build('abc/**/'))
                .to be_like PathList::Matchers::MatchIfDir.new(PathList::Matchers::PathRegexp.new(%r{\A/a/path/abc/}i,
                                                                                                  false))
            end

            it 'matches files or directories inside the mentioned directory when ***' do
              expect(build('abc/***'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/abc/}i, false)
            end
          end

          describe 'A slash followed by two consecutive asterisks then a slash matches zero or more directories.' do
            it 'matches multiple intermediate dirs' do
              expect(build('a/**/b'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a/(?:.*/)?b\z}i, false)
            end

            it 'matches multiple intermediate dirs when ***' do
              expect(build('a/***/b'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/a/(?:.*/)?b\z}i, false)
            end
          end

          describe 'Other consecutive asterisks are considered regular asterisks' do
            describe 'and will match according to the previous rules' do
              context 'with two stars' do
                it 'matches any number of characters at the beginning' do
                  expect(build('**our'))
                    .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/.*our\z}i, false)
                end

                it "doesn't match a slash" do
                  expect(build('f**our'))
                    .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/f[^/]*our\z}i, false)
                end

                it 'matches any number of characters in the middle' do
                  expect(build('f**r'))
                    .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/f[^/]*r\z}i, false)
                end

                it 'matches any number of characters at the end' do
                  expect(build('few**'))
                    .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/few[^/]*\z}i, false)
                end

                # not sure if this is a bug but this is git behaviour
                it 'matches any number of directories including none, when following a character, and anchors' do
                  expect(build('f**/our'))
                    .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/path/f(?:.*/)?our\z}i, false)
                end
              end
            end
          end
        end
      end
    end

    describe 'allow: false, root: "/"' do
      let(:options) { { allow: false, root: '/' } }

      describe 'from the gitignore documentation' do
        describe 'A blank line matches no files, so it can serve as a separator for readability.' do
          it { expect(build('')).to be_like PathList::Matchers::Blank }
          it { expect(build(' ')).to be_like PathList::Matchers::Blank }
          it { expect(build("\t")).to be_like PathList::Matchers::Blank }
        end

        describe 'The simple case' do
          it { expect(build('foo')).to be_like PathList::Matchers::PathRegexp.new(%r{/foo\z}i, false) }
        end

        describe 'A line starting with # serves as a comment.' do
          it { expect(build('#foo')).to be_like PathList::Matchers::Blank }
          it { expect(build('# foo')).to be_like PathList::Matchers::Blank }
          it { expect(build('#')).to be_like PathList::Matchers::Blank }

          it 'must be the first character' do
            expect(build(' #foo'))
              .to be_like PathList::Matchers::PathRegexp.new(%r{/\ \#foo\z}i, false)
          end

          describe 'Put a backslash ("\") in front of the first hash for patterns that begin with a hash' do
            it do
              expect(build('\\#foo'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/\#foo\z}i, false)
            end
          end
        end

        describe 'literal backslashes in filenames' do
          it 'matches an escaped backslash at the end of the pattern' do
            expect(build('foo\\\\'))
              .to be_like PathList::Matchers::PathRegexp.new(%r{/foo\\\z}i, false)
          end

          it 'never matches a literal backslash at the end of the pattern' do
            expect(build('foo\\'))
              .to be_like PathList::Matchers::Blank
          end

          it 'matches an escaped backslash at the start of the pattern' do
            expect(build('\\\\foo'))
              .to be_like PathList::Matchers::PathRegexp.new(%r{/\\foo\z}i, false)
          end

          it 'matches a literal escaped f at the start of the pattern' do
            expect(build('\\foo'))
              .to be_like PathList::Matchers::PathRegexp.new(%r{/foo\z}i, false)
          end
        end

        describe 'Trailing spaces are ignored unless they are quoted with backslash ("\")' do
          it 'ignores trailing spaces in the gitignore file' do
            expect(build('foo  '))
              .to be_like PathList::Matchers::PathRegexp.new(%r{/foo\z}i, false)
          end

          it "doesn't ignore trailing spaces if there's a backslash" do
            expect(build('foo \\ '))
              .to be_like PathList::Matchers::PathRegexp.new(%r{/foo\ \ \z}i, false)
          end

          it 'considers trailing backslashes to never be matched' do
            expect(build('foo\\'))
              .to be_like PathList::Matchers::Blank
          end

          it "doesn't ignore trailing spaces if there's a backslash before every space" do
            expect(build('foo\\ \\ '))
              .to be_like PathList::Matchers::PathRegexp.new(%r{/foo\ \ \z}i, false)
          end

          it "doesn't ignore just that trailing spaces if there's a backslash before the non last space" do
            expect(build('foo\\  '))
              .to be_like PathList::Matchers::PathRegexp.new(%r{/foo\ \z}i, false)
          end
        end

        describe 'If the pattern ends with a slash, it is removed for the purpose of the following description' do
          describe 'but it would only find a match with a directory' do
            # In other words, foo/ will match a directory foo and paths underneath it,
            # but will not match a regular file or a symbolic link foo
            # (this is consistent with the way how pathspec works in general in Git).

            it 'ignores directories but not files or symbolic links that match patterns ending with /' do
              expect(build('foo/'))
                .to be_like PathList::Matchers::MatchIfDir.new(
                  PathList::Matchers::PathRegexp.new(%r{/foo\z}i, false)
               )
            end

            it 'handles this specific edge case i stumbled across' do
              expect(build('Ȋ/'))
                .to be_like PathList::Matchers::MatchIfDir.new(
                  PathList::Matchers::PathRegexp.new(%r{/Ȋ\z}i, false)
               )
            end
          end
        end

        # The slash / is used as the directory separator.
        # Separators may occur at the beginning, middle or end of the .gitignore search pattern.
        describe 'If there is a separator at the beginning or middle (or both) of the pattern' do
          describe 'then the pattern is relative to the directory level of the particular .gitignore file itself.' do
            # For example, a pattern doc/frotz/ matches doc/frotz directory, but not a/doc/frotz directory;
            # The pattern doc/frotz and /doc/frotz have the same effect in any .gitignore file.
            # In other words, a leading slash is not relevant if there is already a middle slash in the pattern.
            it 'includes files relative to the git dir with a middle slash' do
              expect(build('doc/frotz'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/doc/frotz\z}i, false)
            end

            it 'treats a double slash as matching nothing' do
              expect(build('doc//frotz'))
                .to be_like PathList::Matchers::Blank
            end
          end

          describe 'Otherwise the pattern may also match at any level below the .gitignore level.' do
            # frotz/ matches frotz and a/frotz that is a directory

            it 'includes files relative to anywhere with only an end slash' do
              expect(build('frotz/'))
                .to be_like PathList::Matchers::MatchIfDir.new(
                  PathList::Matchers::PathRegexp.new(%r{/frotz\z}i, false)
               )
            end

            it 'strips trailing space before deciding a rule is dir_only' do
              expect(build('frotz/ '))
                .to be_like PathList::Matchers::MatchIfDir.new(
                  PathList::Matchers::PathRegexp.new(%r{/frotz\z}i, false)
               )
            end
          end
        end

        describe 'An optional prefix "!" which negates the pattern' do
          describe 'any matching file excluded by a previous pattern will become included again.' do
            it 'includes previously excluded files' do
              expect(build('!foo'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/foo\z}i, true)
            end
          end

          describe 'Put a backslash ("\") in front of the first "!" for patterns that begin with a literal "!"' do
            # for example, "\!important!.txt".'

            it 'matches files starting with a literal ! if its preceded by a backslash' do
              expect(build('\!important!.txt'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/!important!\.txt\z}i, false)
            end
          end
        end

        describe 'Otherwise, Git treats the pattern as a shell glob' do
          describe '"*" matches anything except "/"' do
            describe 'single level' do
              it "matches any number of characters at the beginning if there's a star" do
                expect(build('*our'))
                  .to be_like PathList::Matchers::PathRegexp.new(/our\z/i, false)
              end

              it "matches any number of characters at the beginning if there's a star followed by a slash" do
                expect(build('*/our'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/[^/]*/our\z}i, false)
              end

              it "doesn't match a slash" do
                expect(build('f*our'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{/f[^/]*our\z}i, false)
              end

              it "matches any number of characters in the middle if there's a star" do
                expect(build('f*r'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{/f[^/]*r\z}i, false)
              end

              it "matches any number of characters at the end if there's a star" do
                expect(build('few*'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{/few[^/]*\z}i, false)
              end
            end

            describe 'multi level' do
              it 'matches a whole directory' do
                expect(build('a/*/c'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/[^/]*/c\z}i, false)
              end

              it 'matches an exact partial match at start' do
                expect(build('a/b*/c'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/b[^/]*/c\z}i, false)
              end

              it 'matches an exact partial match at end' do
                expect(build('a/*b/c'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/[^/]*b/c\z}i, false)
              end

              it 'matches multiple directories when sequential /*/' do
                expect(build('a/*/*'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/[^/]*/[^/]*\z}i, false)
              end

              it 'matches multiple directories when beginning sequential /*/' do
                expect(build('*/*/c'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/[^/]*/[^/]*/c\z}i, false)
              end

              it 'matches multiple directories when ending with /**/*' do
                expect(build('a/**/*'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/}i, false)
              end

              it 'matches multiple directories when ending with **/*' do
                expect(build('a**/*'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a}i, false)
              end

              it 'matches multiple directories when beginning with **/*/' do
                expect(build('**/*/c'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{/c\z}i, false)
              end

              it 'matches multiple directories when beginning with **/*' do
                expect(build('**/*c'))
                  .to be_like PathList::Matchers::PathRegexp.new(/c\z/i, false)
              end
            end
          end

          describe '"?" matches any one character except "/"' do
            it "matches one character at the beginning if there's a ?" do
              expect(build('?our'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/[^/]our\z}i, false)
            end

            it "doesn't match a slash" do
              expect(build('fa?our'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/fa[^/]our\z}i, false)
            end

            it 'matches per ?' do
              expect(build('f??r'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/f[^/][^/]r\z}i, false)
            end

            it "matches a single character at the end if there's a ?" do
              expect(build('fou?'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/fou[^/]\z}i, false)
            end
          end

          describe '"[]" matches one character in a selected range' do
            it 'matches a single character in a character class' do
              expect(build('a[ab]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/a(?!/)[ab]\z}i, false)
            end

            it 'matches a single character in a character class range' do
              expect(build('a[a-c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/a(?!/)[a-c]\z}i, false)
            end

            it 'treats a backward character class range as only the first character of the range' do
              expect(build('a[d-a]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/a(?!/)[d]\z}i, false)
            end

            it 'treats a negated backward character class range as only the first character of the range' do
              expect(build('a[^d-a]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/a(?!/)[^d]\z}i, false)
            end

            it 'treats a escaped backward character class range as only the first character of the range' do
              expect(build('a[\\]-\\[]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/a(?!/)[\]]\z}i, false)
            end

            it 'treats a negated escaped backward character class range as only the first character of the range' do
              expect(build('a[^\\]-\\[]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/a(?!/)[^\]]\z}i, false)
            end

            it 'treats a escaped character class range as as a range' do
              expect(build('a[\\[-\\]]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/a(?!/)[\[-\]]\z}i, false)
            end

            it 'treats a negated escaped character class range as a range' do
              expect(build('a[^\\[-\\]]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/a(?!/)[^\[-\]]\z}i, false)
            end

            it 'treats an unnecessarily escaped character class range as a range' do
              expect(build('a[\\a-\\c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/a(?!/)[a-c]\z}i, false)
            end

            it 'treats a negated unnecessarily escaped character class range as a range' do
              expect(build('a[^\\a-\\c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/a(?!/)[^a-c]\z}i, false)
            end

            it 'treats a backward character class range with other options as only the first character of the range' do
              expect(build('a[d-ba]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/a(?!/)[da]\z}i, false)
            end

            it 'treats a negated backward character class range with other chars as the first character of the range' do
              expect(build('a[^d-ba]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/a(?!/)[^da]\z}i, false)
            end

            it 'treats a backward char class range with other initial options as the first char of the range' do
              expect(build('a[ad-b]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/a(?!/)[ad]\z}i, false)
            end

            it 'treats a negated backward char class range with other initial options as the first char of the range' do
              expect(build('a[^ad-b]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/a(?!/)[^ad]\z}i, false)
            end

            it 'treats a equal character class range as only the first character of the range' do
              expect(build('a[d-d]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/a(?!/)[d]\z}i, false)
            end

            it 'treats a negated equal character class range as only the first character of the range' do
              expect(build('a[^d-d]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/a(?!/)[^d]\z}i, false)
            end

            it 'interprets a / after a character class range as not there' do
              expect(build('a[a-c/]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/a(?!/)[a-c/]\z}i, false)
            end

            it 'interprets a / before a character class range as not there' do
              expect(build('a[/a-c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/a(?!/)[/a-c]\z}i, false)
            end

            # TODO: confirm if that matches a slash character
            it 'interprets a / before the dash in a character class range as any character from / to c' do
              expect(build('a[+/-c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/a(?!/)[\+/-c]\z}i, false)
            end

            it 'interprets a / after the dash in a character class range as any character from start to /' do
              expect(build('a["-/c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/a(?!/)["-/c]\z}i, false)
            end

            it 'interprets a slash then dash then character to be a character range' do
              expect(build('a[/-c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/a(?!/)[/-c]\z}i, false)
            end

            it 'interprets a character then dash then slash to be a character range' do
              expect(build('a["-/]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/a(?!/)["-/]\z}i, false)
            end

            context 'without raising warnings' do
              # these edge cases raise warnings
              # they're edge-casey enough if you hit them you deserve warnings.
              before { allow(Warning).to receive(:warn) }

              it 'interprets dash dash character as a character range beginning with -' do
                expect(build('a[--c]'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{/a(?!/)[\--c]\z}i, false)
              end

              it 'interprets character dash dash as a character range ending with -' do
                expect(build('a["--]'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{/a(?!/)["-\-]\z}i, false)
              end

              it 'interprets dash dash dash as a character range of only with -' do
                expect(build('a[---]'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{/a(?!/)[\-]\z}i, false)
              end

              it 'interprets character dash dash dash as a character range of only with " to - with literal -' do
                # for some reason this as a regexp literal triggers the warning raise
                # and building it with Regexp.new results in a regexp that is identical but not equal
                expect(build('a["---]'))
                  .to be_like PathList::Matchers::PathRegexp.new(
                    Regexp.new('/a(?!\/)["-\\-\\-]\\z', 1), false
                 )
              end

              it 'interprets dash dash dash character as a character range of only - with literal c' do
                expect(build('a[---c]'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{/a(?!/)[\-c]\z}i, false)
              end

              it 'interprets character dash dash character as a character range ending with - and a literal c' do
                # this could just as easily be interpreted the other way around (" is the literal, --c is the range),
                # but ruby regex and git seem to treat this edge case the same
                expect(build('a["--c]'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{/a(?!/)["-\-c]\z}i, false)
              end
            end

            it '^ is not' do
              expect(build('a[^a-c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/a(?!/)[^a-c]\z}i, false)
            end

            # this doesn't appear to be documented anywhere i just stumbled onto it
            it '! is also not' do
              expect(build('a[!a-c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/a(?!/)[^a-c]\z}i, false)
            end

            it '[^/] matches everything' do
              expect(build('a[^/]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/a(?!/)[^/]\z}i, false)
            end

            it '[^^] matches everything except literal ^' do
              expect(build('a[^^]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/a(?!/)[^\^]\z}i, false)
            end

            it '[^/a] matches everything except a' do
              expect(build('a[^/a]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/a(?!/)[^/a]\z}i, false)
            end

            it '[/^a] matches literal ^ and a' do
              expect(build('a[/^a]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/a(?!/)[/\^a]\z}i, false)
            end

            it '[/^] matches literal ^' do
              expect(build('a[/^]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/a(?!/)[/\^]\z}i, false)
            end

            it '[\\^] matches literal ^' do
              expect(build('a[\^]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/a(?!/)[\^]\z}i, false)
            end

            it 'later ^ is literal' do
              expect(build('a[a-c^]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/a(?!/)[a-c\^]\z}i, false)
            end

            it "doesn't match a slash even if you specify it last" do
              expect(build('b[i/]b'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/b(?!/)[i/]b\z}i, false)
            end

            it "doesn't match a slash even if you specify it alone" do
              expect(build('b[/]b'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/b(?!/)[/]b\z}i, false)
            end

            it 'empty class matches nothing' do
              expect(build('b[]b'))
                .to be_like PathList::Matchers::Blank
            end

            it "doesn't match a slash even if you specify it middle" do
              expect(build('b[i/a]b'))
                .to be_like PathList::Matchers::PathRegexp.new(
                  %r{/b(?!/)[i/a]b\z}i, false
               )
            end

            it "doesn't match a slash even if you specify it start" do
              expect(build('b[/ai]b'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/b(?!/)[/ai]b\z}i, false)
            end

            it 'assumes an unfinished [ matches nothing' do
              expect(build('a['))
                .to be_like PathList::Matchers::Blank
            end

            it 'assumes an unfinished [ followed by \ matches nothing' do
              expect(build('a[\\'))
                .to be_like PathList::Matchers::Blank
            end

            it 'assumes an escaped [ is literal' do
              expect(build('a\\['))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/a\[\z}i, false)
            end

            it 'assumes an escaped [ is literal inside a group' do
              expect(build('a[\\[]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/a(?!/)[\[]\z}i, false)
            end

            it 'assumes an unfinished [ matches nothing when negated' do
              expect(build('!a['))
                .to be_like PathList::Matchers::Blank
            end

            it 'assumes an unfinished [bc matches nothing' do
              expect(build('a[bc'))
                .to be_like PathList::Matchers::Blank
            end
          end

          # See fnmatch(3) and the FNM_PATHNAME flag for a more detailed description
        end

        describe 'A leading slash matches the beginning of the pathname.' do
          # For example, "/*.c" matches "cat-file.c" but not "mozilla-sha1/sha1.c".
          it 'matches only at the beginning of everything' do
            expect(build('/*.c'))
              .to be_like PathList::Matchers::PathRegexp.new(%r{\A/[^/]*\.c\z}i, false)
          end
        end

        describe 'Two consecutive asterisks ("**") in patterns matched against full pathname has special meaning:' do
          describe 'A leading "**" followed by a slash means match in all directories.' do
            # 'For example, "**/foo" matches file or directory "foo" anywhere, the same as pattern "foo".
            # "**/foo/bar" matches file or directory "bar" anywhere that is directly under directory "foo".'

            it 'matches files or directories in all directories' do
              expect(build('**/foo'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/foo\z}i, false)
            end

            it 'matches nothing with double slash' do
              expect(build('**//foo'))
                .to be_like PathList::Matchers::Blank
            end

            it 'matches all directories when only **/ (interpreted as ** then the trailing / for dir only)' do
              expect(build('**/'))
                .to be_like PathList::Matchers::MatchIfDir.new(PathList::Matchers::Ignore)
            end

            it 'matches files or directories in all directories when repeated' do
              expect(build('**/**/foo'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/foo\z}i, false)
            end

            it 'matches files or directories in all directories with **/*' do
              expect(build('**/*'))
                .to be_like PathList::Matchers::Ignore
            end

            it 'matches files or directories in all directories when also followed by a star before text' do
              expect(build('**/*foo'))
                .to be_like PathList::Matchers::PathRegexp.new(/foo\z/i, false)
            end

            it 'matches files or directories in all directories when also followed by a star within text' do
              expect(build('**/f*o'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/f[^/]*o\z}i, false)
            end

            it 'matches files or directories in all directories when also followed by a star after text' do
              expect(build('**/fo*'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/fo[^/]*\z}i, false)
            end

            it 'matches files or directories in all directories when three stars' do
              expect(build('***/foo'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{/foo\z}i, false)
            end
          end

          describe 'A trailing "/**" matches everything inside relative to the location of the .gitignore file.' do
            it 'matches files or directories inside the mentioned directory' do
              expect(build('abc/**'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/abc/}i, false)
            end

            it 'matches all directories inside the mentioned directory' do
              expect(build('abc/**/'))
                .to be_like PathList::Matchers::MatchIfDir.new(PathList::Matchers::PathRegexp.new(%r{\A/abc/}i, false))
            end

            it 'matches files or directories inside the mentioned directory when ***' do
              expect(build('abc/***'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/abc/}i, false)
            end
          end

          describe 'A slash followed by two consecutive asterisks then a slash matches zero or more directories.' do
            it 'matches multiple intermediate dirs' do
              expect(build('a/**/b'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/(?:.*/)?b\z}i, false)
            end

            it 'matches multiple intermediate dirs when ***' do
              expect(build('a/***/b'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\A/a/(?:.*/)?b\z}i, false)
            end
          end

          describe 'Other consecutive asterisks are considered regular asterisks' do
            describe 'and will match according to the previous rules' do
              context 'with two stars' do
                it 'matches any number of characters at the beginning' do
                  expect(build('**our'))
                    .to be_like PathList::Matchers::PathRegexp.new(/our\z/i, false)
                end

                it "doesn't match a slash" do
                  expect(build('f**our'))
                    .to be_like PathList::Matchers::PathRegexp.new(%r{/f[^/]*our\z}i, false)
                end

                it 'matches any number of characters in the middle' do
                  expect(build('f**r'))
                    .to be_like PathList::Matchers::PathRegexp.new(%r{/f[^/]*r\z}i, false)
                end

                it 'matches any number of characters at the end' do
                  expect(build('few**'))
                    .to be_like PathList::Matchers::PathRegexp.new(%r{/few[^\/]*\z}i, false)
                end

                # not sure if this is a bug but this is git behaviour
                it 'matches any number of directories including none, when following a character, and anchors' do
                  expect(build('f**/our'))
                    .to be_like PathList::Matchers::PathRegexp.new(%r{\A/f(?:.*/)?our\z}i, false)
                end
              end
            end
          end
        end
      end
    end

    describe 'allow: true, root: nil', skip: 'root: nil is broken' do
      let(:options) { { allow: true, root: nil } }

      describe 'from the gitignore documentation' do
        describe 'A blank line matches no files, so it can serve as a separator for readability.' do
          it { expect(build('')).to be_like PathList::Matchers::Blank }
          it { expect(build(' ')).to be_like PathList::Matchers::Blank }
          it { expect(build("\t")).to be_like PathList::Matchers::Blank }
        end

        describe 'The simple case' do
          it { expect(build('foo')).to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\z}i, true) }
        end

        describe 'A line starting with # serves as a comment.' do
          it { expect(build('#foo')).to be_like PathList::Matchers::Blank }
          it { expect(build('# foo')).to be_like PathList::Matchers::Blank }
          it { expect(build('#')).to be_like PathList::Matchers::Blank }

          it 'must be the first character' do
            expect(build(' #foo'))
              .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)\ \#foo\z}i, true)
          end

          describe 'Put a backslash ("\") in front of the first hash for patterns that begin with a hash' do
            it do
              expect(build('\\#foo'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)\#foo\z}i, true)
            end
          end
        end

        describe 'literal backslashes in filenames' do
          it 'matches an escaped backslash at the end of the pattern' do
            expect(build('foo\\\\'))
              .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\\\z}i, true)
          end

          it 'never matches a literal backslash at the end of the pattern' do
            expect(build('foo\\'))
              .to be_like PathList::Matchers::Invalid
          end

          it 'matches an escaped backslash at the start of the pattern' do
            expect(build('\\\\foo'))
              .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)\\foo\z}i, true)
          end

          it 'matches a literal escaped f at the start of the pattern' do
            expect(build('\\foo'))
              .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\z}i, true)
          end
        end

        describe 'Trailing spaces are ignored unless they are quoted with backslash ("\")' do
          it 'ignores trailing spaces in the gitignore file' do
            expect(build('foo  '))
              .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\z}i, true)
          end

          it "doesn't ignore trailing spaces if there's a backslash" do
            expect(build('foo \\ '))
              .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\ \ \z}i, true)
          end

          it 'considers trailing backslashes to never be matched' do
            expect(build('foo\\'))
              .to be_like PathList::Matchers::Invalid
          end

          it "doesn't ignore trailing spaces if there's a backslash before every space" do
            expect(build('foo\\ \\ '))
              .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\ \ \z}i, true)
          end

          it "doesn't ignore just that trailing spaces if there's a backslash before the non last space" do
            expect(build('foo\\  '))
              .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\ \z}i, true)
          end
        end

        describe 'If the pattern ends with a slash, it is removed for the purpose of the following description' do
          describe 'but it would only find a match with a directory' do
            # In other words, foo/ will match a directory foo and paths underneath it,
            # but will not match a regular file or a symbolic link foo
            # (this is consistent with the way how pathspec works in general in Git).

            it 'ignores directories but not files or symbolic links that match patterns ending with /' do
              expect(build('foo/'))
                .to be_like PathList::Matchers::MatchIfDir.new(
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\z}i, true)
               )
            end

            it 'handles this specific edge case i stumbled across' do
              expect(build('Ȋ/'))
                .to be_like PathList::Matchers::MatchIfDir.new(
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)Ȋ\z}i, true)
               )
            end
          end
        end

        # The slash / is used as the directory separator.
        # Separators may occur at the beginning, middle or end of the .gitignore search pattern.
        describe 'If there is a separator at the beginning or middle (or both) of the pattern' do
          describe 'then the pattern is relative to the directory level of the particular .gitignore file itself.' do
            # For example, a pattern doc/frotz/ matches doc/frotz directory, but not a/doc/frotz directory;
            # The pattern doc/frotz and /doc/frotz have the same effect in any .gitignore file.
            # In other words, a leading slash is not relevant if there is already a middle slash in the pattern.
            it 'includes files relative to the git dir with a middle slash' do
              expect(build('doc/frotz'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\Adoc/frotz\z}i, true)
            end

            it 'treats a double slash as matching nothing' do
              expect(build('doc//frotz'))
                .to be_like PathList::Matchers::Invalid
            end
          end

          describe 'Otherwise the pattern may also match at any level below the .gitignore level.' do
            # frotz/ matches frotz and a/frotz that is a directory

            it 'includes files relative to anywhere with only an end slash' do
              expect(build('frotz/'))
                .to be_like PathList::Matchers::MatchIfDir.new(
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)frotz\z}i, true)
               )
            end

            it 'strips trailing space before deciding a rule is dir_only' do
              expect(build('frotz/ '))
                .to be_like PathList::Matchers::MatchIfDir.new(
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)frotz\z}i, true)
               )
            end
          end
        end

        describe 'An optional prefix "!" which negates the pattern' do
          describe 'any matching file excluded by a previous pattern will become included again.' do
            it 'includes previously excluded files' do
              expect(build('!foo'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\z}i, false)
            end
          end

          describe 'Put a backslash ("\") in front of the first "!" for patterns that begin with a literal "!"' do
            # for example, "\!important!.txt".'

            it 'matches files starting with a literal ! if its preceded by a backslash' do
              expect(build('\!important!.txt'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)!important!\.txt\z}i, true)
            end
          end
        end

        describe 'Otherwise, Git treats the pattern as a shell glob' do
          describe '"*" matches anything except "/"' do
            describe 'single level' do
              it "matches any number of characters at the beginning if there's a star" do
                expect(build('*our'))
                  .to be_like PathList::Matchers::PathRegexp.new(/our\z/i, true)
              end

              it "matches any number of characters at the beginning if there's a star followed by a slash" do
                expect(build('*/our'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A[^/]*/our\z}i, true)
              end

              it "doesn't match a slash" do
                expect(build('f*our'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)f[^/]*our\z}i, true)
              end

              it "matches any number of characters in the middle if there's a star" do
                expect(build('f*r'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)f[^/]*r\z}i, true)
              end

              it "matches any number of characters at the end if there's a star" do
                expect(build('few*'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)few[^/]*\z}i, true)
              end
            end

            describe 'multi level' do
              it 'matches a whole directory' do
                expect(build('a/*/c'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\Aa/[^/]*/c\z}i, true)
              end

              it 'matches an exact partial match at start' do
                expect(build('a/b*/c'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\Aa/b[^/]*/c\z}i, true)
              end

              it 'matches an exact partial match at end' do
                expect(build('a/*b/c'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\Aa/[^/]*b/c\z}i, true)
              end

              it 'matches multiple directories when sequential /*/' do
                expect(build('a/*/*'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\Aa/[^/]*/[^/]+\z}i, true)
              end

              it 'matches multiple directories when beginning sequential /*/' do
                expect(build('*/*/c'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\A[^/]*/[^/]*/c\z}i, true)
              end

              it 'matches multiple directories when ending with /**/*' do
                expect(build('a/**/*'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\Aa/(?:.*/)?[^/]+\z}i, true)
              end

              it 'matches multiple directories when ending with **/*' do
                expect(build('a**/*'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{\Aa(?:.*/)?[^/]+\z}i, true)
              end

              it 'matches multiple directories when beginning with **/*/' do
                expect(build('**/*/c'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{/c\z}i, true)
              end

              it 'matches multiple directories when beginning with **/*' do
                expect(build('**/*c'))
                  .to be_like PathList::Matchers::PathRegexp.new(/c\z/i, true)
              end
            end
          end

          describe '"?" matches any one character except "/"' do
            it "matches one character at the beginning if there's a ?" do
              expect(build('?our'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)[^/]our\z}i, true)
            end

            it "doesn't match a slash" do
              expect(build('fa?our'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)fa[^/]our\z}i, true)
            end

            it 'matches per ?' do
              expect(build('f??r'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)f[^/][^/]r\z}i, true)
            end

            it "matches a single character at the end if there's a ?" do
              expect(build('fou?'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)fou[^/]\z}i, true)
            end
          end

          describe '"[]" matches one character in a selected range' do
            it 'matches a single character in a character class' do
              expect(build('a[ab]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[ab]\z}i, true)
            end

            it 'matches a single character in a character class range' do
              expect(build('a[a-c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[a-c]\z}i, true)
            end

            it 'treats a backward character class range as only the first character of the range' do
              expect(build('a[d-a]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[d]\z}i, true)
            end

            it 'treats a negated backward character class range as only the first character of the range' do
              expect(build('a[^d-a]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^d]\z}i, true)
            end

            it 'treats a escaped backward character class range as only the first character of the range' do
              expect(build('a[\\]-\\[]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[\]]\z}i, true)
            end

            it 'treats a negated escaped backward character class range as only the first character of the range' do
              expect(build('a[^\\]-\\[]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^\]]\z}i, true)
            end

            it 'treats a escaped character class range as as a range' do
              expect(build('a[\\[-\\]]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[\[-\]]\z}i, true)
            end

            it 'treats a negated escaped character class range as a range' do
              expect(build('a[^\\[-\\]]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^\[-\]]\z}i, true)
            end

            it 'treats an unnecessarily escaped character class range as a range' do
              expect(build('a[\\a-\\c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[a-c]\z}i, true)
            end

            it 'treats a negated unnecessarily escaped character class range as a range' do
              expect(build('a[^\\a-\\c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^a-c]\z}i, true)
            end

            it 'treats a backward character class range with other options as only the first character of the range' do
              expect(build('a[d-ba]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[da]\z}i, true)
            end

            it 'treats a negated backward character class range with other chars as the first character of the range' do
              expect(build('a[^d-ba]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^da]\z}i, true)
            end

            it 'treats a backward char class range with other initial options as the first char of the range' do
              expect(build('a[ad-b]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[ad]\z}i, true)
            end

            it 'treats a negated backward char class range with other initial options as the first char of the range' do
              expect(build('a[^ad-b]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^ad]\z}i, true)
            end

            it 'treats a equal character class range as only the first character of the range' do
              expect(build('a[d-d]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[d]\z}i, true)
            end

            it 'treats a negated equal character class range as only the first character of the range' do
              expect(build('a[^d-d]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^d]\z}i, true)
            end

            it 'interprets a / after a character class range as not there' do
              expect(build('a[a-c/]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[a-c/]\z}i, true)
            end

            it 'interprets a / before a character class range as not there' do
              expect(build('a[/a-c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[/a-c]\z}i, true)
            end

            # TODO: confirm if that matches a slash character
            it 'interprets a / before the dash in a character class range as any character from / to c' do
              expect(build('a[+/-c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[\+/-c]\z}i, true)
            end

            it 'interprets a / after the dash in a character class range as any character from start to /' do
              expect(build('a["-/c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)["-/c]\z}i, true)
            end

            it 'interprets a slash then dash then character to be a character range' do
              expect(build('a[/-c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[/-c]\z}i, true)
            end

            it 'interprets a character then dash then slash to be a character range' do
              expect(build('a["-/]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)["-/]\z}i, true)
            end

            context 'without raising warnings' do
              # these edge cases raise warnings
              # they're edge-casey enough if you hit them you deserve warnings.
              before { allow(Warning).to receive(:warn) }

              it 'interprets dash dash character as a character range beginning with -' do
                expect(build('a[--c]'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[\--c]\z}i, true)
              end

              it 'interprets character dash dash as a character range ending with -' do
                expect(build('a["--]'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)["-\-]\z}i, true)
              end

              it 'interprets dash dash dash as a character range of only with -' do
                expect(build('a[---]'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[\-]\z}i, true)
              end

              it 'interprets character dash dash dash as a character range of only with " to - with literal -' do
                # for some reason this as a regexp literal triggers the warning raise
                expect(build('a["---]')).to be_like PathList::Matchers::PathRegexp.new(
                  Regexp.new('(?:\\A|\/)a(?!\/)["-\\-\\-]\\z', 1), true
               )
              end

              it 'interprets dash dash dash character as a character range of only - with literal c' do
                expect(build('a[---c]'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[\-c]\z}i, true)
              end

              it 'interprets character dash dash character as a character range ending with - and a literal c' do
                # this could just as easily be interpreted the other way around (" is the literal, --c is the range),
                # but ruby regex and git seem to treat this edge case the same
                expect(build('a["--c]'))
                  .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)["-\-c]\z}i, true)
              end
            end

            it '^ is not' do
              expect(build('a[^a-c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^a-c]\z}i, true)
            end

            # this doesn't appear to be documented anywhere i just stumbled onto it
            it '! is also not' do
              expect(build('a[!a-c]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^a-c]\z}i, true)
            end

            it '[^/] matches everything' do
              expect(build('a[^/]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^/]\z}i, true)
            end

            it '[^^] matches everything except literal ^' do
              expect(build('a[^^]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^\^]\z}i, true)
            end

            it '[^/a] matches everything except a' do
              expect(build('a[^/a]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^/a]\z}i, true)
            end

            it '[/^a] matches literal ^ and a' do
              expect(build('a[/^a]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[/\^a]\z}i, true)
            end

            it '[/^] matches literal ^' do
              expect(build('a[/^]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[/\^]\z}i, true)
            end

            it '[\\^] matches literal ^' do
              expect(build('a[\^]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[\^]\z}i, true)
            end

            it 'later ^ is literal' do
              expect(build('a[a-c^]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[a-c\^]\z}i, true)
            end

            it "doesn't match a slash even if you specify it last" do
              expect(build('b[i/]b'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)b(?!/)[i/]b\z}i, true)
            end

            it "doesn't match a slash even if you specify it alone" do
              expect(build('b[/]b'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)b(?!/)[/]b\z}i, true)
            end

            it 'empty class matches nothing' do
              expect(build('b[]b'))
                .to be_like PathList::Matchers::Invalid
            end

            it "doesn't match a slash even if you specify it middle" do
              expect(build('b[i/a]b'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)b(?!/)[i/a]b\z}i, true)
            end

            it "doesn't match a slash even if you specify it start" do
              expect(build('b[/ai]b'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)b(?!/)[/ai]b\z}i, true)
            end

            it 'assumes an unfinished [ matches nothing' do
              expect(build('a['))
                .to be_like PathList::Matchers::Invalid
            end

            it 'assumes an unfinished [ followed by \ matches nothing' do
              expect(build('a[\\'))
                .to be_like PathList::Matchers::Invalid
            end

            it 'assumes an escaped [ is literal' do
              expect(build('a\\['))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a\[\z}i, true)
            end

            it 'assumes an escaped [ is literal inside a group' do
              expect(build('a[\\[]'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[\[]\z}i, true)
            end

            it 'assumes an unfinished [ matches nothing when negated' do
              expect(build('!a['))
                .to be_like PathList::Matchers::Invalid
            end

            it 'assumes an unfinished [bc matches nothing' do
              expect(build('a[bc'))
                .to be_like PathList::Matchers::Invalid
            end
          end

          # See fnmatch(3) and the FNM_PATHNAME flag for a more detailed description
        end

        describe 'A leading slash matches the beginning of the pathname.' do
          # For example, "/*.c" matches "cat-file.c" but not "mozilla-sha1/sha1.c".
          it 'matches only at the beginning of everything' do
            expect(build('/*.c'))
              .to be_like PathList::Matchers::PathRegexp.new(%r{\A[^/]*\.c\z}i, true)
          end
        end

        describe 'Two consecutive asterisks ("**") in patterns matched against full pathname has a special meaning:' do
          describe 'A leading "**" followed by a slash means match in all directories.' do
            # 'For example, "**/foo" matches file or directory "foo" anywhere, the same as pattern "foo".
            # "**/foo/bar" matches file or directory "bar" anywhere that is directly under directory "foo".'

            it 'matches files or directories in all directories' do
              expect(build('**/foo'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\z}i, true)
            end

            it 'matches nothing with double slash' do
              expect(build('**//foo'))
                .to be_like PathList::Matchers::Invalid
            end

            it 'matches all directories when only **/ (interpreted as ** then the trailing / for dir only)' do
              expect(build('**/'))
                .to be_like PathList::Matchers::MatchIfDir.new(PathList::Matchers::Allow)
            end

            it 'matches files or directories in all directories when repeated' do
              expect(build('**/**/foo'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\z}i, true)
            end

            it 'matches files or directories in all directories with **/*' do
              expect(build('**/*'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{[^/]\z}i, true)
            end

            it 'matches files or directories in all directories when also followed by a star before text' do
              expect(build('**/*foo'))
                .to be_like PathList::Matchers::PathRegexp.new(/foo\z/i, true)
            end

            it 'matches files or directories in all directories when also followed by a star within text' do
              expect(build('**/f*o'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)f[^/]*o\z}i, true)
            end

            it 'matches files or directories in all directories when also followed by a star after text' do
              expect(build('**/fo*'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)fo[^/]*\z}i, true)
            end

            it 'matches files or directories in all directories when three stars' do
              expect(build('***/foo'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\z}i, true)
            end
          end

          describe 'A trailing "/**" matches everything inside relative to the location of the .gitignore file.' do
            it 'matches files or directories inside the mentioned directory' do
              expect(build('abc/**'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\Aabc/}i, true)
            end

            it 'matches all directories inside the mentioned directory' do
              expect(build('abc/**/'))
                .to be_like PathList::Matchers::MatchIfDir.new(PathList::Matchers::PathRegexp.new(%r{\Aabc/}i, true))
            end

            it 'matches files or directories inside the mentioned directory when ***' do
              expect(build('abc/***'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\Aabc/}i, true)
            end
          end

          describe 'A slash followed by two consecutive asterisks then a slash matches zero or more directories.' do
            it 'matches multiple intermediate dirs' do
              expect(build('a/**/b'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\Aa/(?:.*/)?b\z}i, true)
            end

            it 'matches multiple intermediate dirs when ***' do
              expect(build('a/***/b'))
                .to be_like PathList::Matchers::PathRegexp.new(%r{\Aa/(?:.*/)?b\z}i, true)
            end
          end

          describe 'Other consecutive asterisks are considered regular asterisks' do
            describe 'and will match according to the previous rules' do
              context 'with two stars' do
                it 'matches any number of characters at the beginning' do
                  expect(build('**our'))
                    .to be_like PathList::Matchers::PathRegexp.new(/our\z/i, true)
                end

                it "doesn't match a slash" do
                  expect(build('f**our'))
                    .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)f[^/]*our\z}i, true)
                end

                it 'matches any number of characters in the middle' do
                  expect(build('f**r'))
                    .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)f[^/]*r\z}i, true)
                end

                it 'matches any number of characters at the end' do
                  expect(build('few**'))
                    .to be_like PathList::Matchers::PathRegexp.new(%r{(?:\A|/)few}i, true)
                end

                # not sure if this is a bug but this is git behaviour
                it 'matches any number of directories including none, when following a character, and anchors' do
                  expect(build('f**/our'))
                    .to be_like PathList::Matchers::PathRegexp.new(%r{\Af(?:.*/)?our\z}i, true)
                end
              end
            end
          end
        end
      end
    end
  end

  describe '#build_implicit' do
    let(:method_name) { :build_implicit }

    describe 'allow: false, root: nil', skip: 'root: nil is broken' do
      let(:options) { { allow: false, root: nil } }

      describe 'always blank' do
        it { expect(build('')).to be_like PathList::Matchers::Blank }
        it { expect(build('whatever')).to be_like PathList::Matchers::Blank }
        it { expect(build('/*/**?e8a/ae8ae///*//*/')).to be_like PathList::Matchers::Blank }
      end
    end

    describe 'allow: true, root: nil', skip: 'root: nil is broken' do
      let(:options) { { allow: true, root: nil } }

      describe 'from the gitignore documentation' do
        describe 'A blank line matches no files, so it can serve as a separator for readability.' do
          it { expect(build('')).to be_like PathList::Matchers::Blank }
          it { expect(build(' ')).to be_like PathList::Matchers::Blank }
          it { expect(build("\t")).to be_like PathList::Matchers::Blank }
        end

        describe 'The simple case' do
          it 'matches that filename at every level' do
            expect(build('foo')).to be_like PathList::Matchers::Any::Two.new([
              PathList::Matchers::AllowAnyDir,
              PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo/}i, true)
           ])
          end
        end

        describe 'A line starting with # serves as a comment.' do
          it { expect(build('#foo')).to be_like PathList::Matchers::Blank }
          it { expect(build('# foo')).to be_like PathList::Matchers::Blank }
          it { expect(build('#')).to be_like PathList::Matchers::Blank }

          it 'must be the first character' do
            expect(build(' #foo'))
              .to be_like PathList::Matchers::Any::Two.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)\ \#foo/}i, true)
             ])
          end

          describe 'Put a backslash ("\") in front of the first hash for patterns that begin with a hash' do
            it do
              expect(build('\\#foo'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)\#foo/}i, true)
               ])
            end
          end
        end

        describe 'literal backslashes in filenames' do
          it 'matches an escaped backslash at the end of the pattern' do
            expect(build('foo\\\\'))
              .to be_like PathList::Matchers::Any::Two.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\\/}i, true)
             ])
          end

          it 'never matches a literal backslash at the end of the pattern' do
            expect(build('foo\\'))
              .to be_like PathList::Matchers::Invalid
          end

          it 'matches an escaped backslash at the start of the pattern' do
            expect(build('\\\\foo'))
              .to be_like PathList::Matchers::Any::Two.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)\\foo/}i, true)
             ])
          end

          it 'matches a literal escaped f at the start of the pattern' do
            expect(build('\\foo'))
              .to be_like PathList::Matchers::Any::Two.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo/}i, true)
             ])
          end
        end

        describe 'Trailing spaces are ignored unless they are quoted with backslash ("\")' do
          it 'ignores trailing spaces in the gitignore file' do
            expect(build('foo  '))
              .to be_like PathList::Matchers::Any::Two.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo/}i, true)
             ])
          end

          it "doesn't ignore trailing spaces if there's a backslash" do
            expect(build('foo \\ '))
              .to be_like PathList::Matchers::Any::Two.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\ \ /}i, true)
             ])
          end

          it 'considers trailing backslashes to never be matched' do
            expect(build('foo\\'))
              .to be_like PathList::Matchers::Invalid
          end

          it "doesn't ignore trailing spaces if there's a backslash before every space" do
            expect(build('foo\\ \\ '))
              .to be_like PathList::Matchers::Any::Two.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\ \ /}i, true)
             ])
          end

          it "doesn't ignore just that trailing spaces if there's a backslash before the non last space" do
            expect(build('foo\\  '))
              .to be_like PathList::Matchers::Any::Two.new([
                PathList::Matchers::AllowAnyDir,
                PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo\ /}i, true)
             ])
          end
        end

        describe 'If the pattern ends with a slash, it is removed for the purpose of the following description' do
          describe 'but it would only find a match with a directory' do
            # In other words, foo/ will match a directory foo and paths underneath it,
            # but will not match a regular file or a symbolic link foo
            # (this is consistent with the way how pathspec works in general in Git).

            it 'ignores directories but not files or symbolic links that match patterns ending with /' do
              expect(build('foo/'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo/}i, true)
               ])
            end

            it 'handles this specific edge case i stumbled across' do
              expect(build('Ȋ/'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)Ȋ/}i, true)
               ])
            end
          end
        end

        # The slash / is used as the directory separator.
        # Separators may occur at the beginning, middle or end of the .gitignore search pattern.
        describe 'If there is a separator at the beginning or middle (or both) of the pattern' do
          describe 'then the pattern is relative to the directory level of the particular .gitignore file itself.' do
            # For example, a pattern doc/frotz/ matches doc/frotz directory, but not a/doc/frotz directory;
            # The pattern doc/frotz and /doc/frotz have the same effect in any .gitignore file.
            # In other words, a leading slash is not relevant if there is already a middle slash in the pattern.
            it 'includes files relative to the git dir with a middle slash' do
              expect(build('doc/frotz'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(PathList::Matchers::PathRegexp.new(/\Adoc\z/i, true)),
                  PathList::Matchers::PathRegexp.new(%r{\Adoc/frotz/}i, true)
               ])
            end

            it 'treats a double slash as matching nothing' do
              expect(build('doc//frotz'))
                .to be_like PathList::Matchers::Invalid
            end
          end

          describe 'Otherwise the pattern may also match at any level below the .gitignore level.' do
            # frotz/ matches frotz and a/frotz that is a directory

            it 'includes files relative to anywhere with only an end slash' do
              expect(build('frotz/'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)frotz/}i, true)
               ])
            end

            it 'strips trailing space before deciding a rule is dir_only' do
              expect(build('frotz/ '))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)frotz/}i, true)
               ])
            end
          end
        end

        describe 'An optional prefix "!" which negates the pattern' do
          describe 'any matching file excluded by a previous pattern will become included again.' do
            it 'includes previously excluded files' do
              expect(build('!foo'))
                .to be_like PathList::Matchers::Blank
            end
          end

          describe 'Put a backslash ("\") in front of the first "!" for patterns that begin with a literal "!"' do
            # for example, "\!important!.txt".'

            it 'matches files starting with a literal ! if its preceded by a backslash' do
              expect(build('\!important!.txt'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)!important!\.txt/}i, true)
               ])
            end
          end
        end

        describe 'Otherwise, Git treats the pattern as a shell glob' do
          describe '"*" matches anything except "/"' do
            describe 'single level' do
              it "matches any number of characters at the beginning if there's a star" do
                expect(build('*our'))
                  .to be_like PathList::Matchers::Any::Two.new([
                    PathList::Matchers::AllowAnyDir,
                    PathList::Matchers::PathRegexp.new(%r{our/}i, true)
                 ])
              end

              it "matches any number of characters at the beginning if there's a star followed by a slash" do
                expect(build('*/our'))
                  .to be_like PathList::Matchers::Any::Two.new([
                    PathList::Matchers::MatchIfDir.new(PathList::Matchers::PathRegexp.new(%r{\A[^/]}i, true)),
                    PathList::Matchers::PathRegexp.new(%r{\A[^/]*/our/}i, true)
                 ])
              end

              it "doesn't match a slash" do
                expect(build('f*our'))
                  .to be_like PathList::Matchers::Any::Two.new([
                    PathList::Matchers::AllowAnyDir,
                    PathList::Matchers::PathRegexp.new(%r{(?:\A|/)f[^/]*our/}i, true)
                 ])
              end

              it "matches any number of characters in the middle if there's a star" do
                expect(build('f*r'))
                  .to be_like PathList::Matchers::Any::Two.new([
                    PathList::Matchers::AllowAnyDir,
                    PathList::Matchers::PathRegexp.new(%r{(?:\A|/)f[^/]*r/}i, true)
                 ])
              end

              it "matches any number of characters at the end if there's a star" do
                expect(build('few*'))
                  .to be_like PathList::Matchers::Any::Two.new([
                    PathList::Matchers::AllowAnyDir,
                    PathList::Matchers::PathRegexp.new(%r{(?:\A|/)few[^/]*/}i, true)
                 ])
              end
            end

            describe 'multi level' do
              it 'matches a whole directory' do
                expect(build('a/*/c'))
                  .to be_like PathList::Matchers::Any::Two.new([
                    PathList::Matchers::MatchIfDir.new(
                      PathList::Matchers::PathRegexp.new(%r{\Aa(?:\z|/[^/]*\z)}i, true)
                    ),
                    PathList::Matchers::PathRegexp.new(%r{\Aa/[^/]*/c/}i, true)
                 ])
              end

              it 'matches an exact partial match at start' do
                expect(build('a/b*/c'))
                  .to be_like PathList::Matchers::Any::Two.new([
                    PathList::Matchers::MatchIfDir.new(
                      PathList::Matchers::PathRegexp.new(%r{\Aa(?:\z|/b[^/]*\z)}i, true)
                    ),
                    PathList::Matchers::PathRegexp.new(%r{\Aa/b[^/]*/c/}i, true)
                 ])
              end

              it 'matches an exact partial match at end' do
                expect(build('a/*b/c'))
                  .to be_like PathList::Matchers::Any::Two.new([
                    PathList::Matchers::MatchIfDir.new(
                      PathList::Matchers::PathRegexp.new(%r{\Aa(?:\z|/[^/]*b\z)}i, true)
                    ),
                    PathList::Matchers::PathRegexp.new(%r{\Aa/[^/]*b/c/}i, true)
                 ])
              end

              it 'matches multiple directories when sequential /*/' do
                expect(build('a/*/*'))
                  .to be_like PathList::Matchers::Any::Two.new([
                    PathList::Matchers::MatchIfDir.new(
                      PathList::Matchers::PathRegexp.new(%r{\Aa(?:\z|/[^/]*\z)}i, true)
                    ),
                    PathList::Matchers::PathRegexp.new(%r{\Aa/[^/]*/[^/]+/}i, true)
                 ])
              end

              it 'matches multiple directories when beginning sequential /*/' do
                expect(build('*/*/c'))
                  .to be_like PathList::Matchers::Any::Two.new([
                    PathList::Matchers::MatchIfDir.new(
                      PathList::Matchers::PathRegexp.new(%r{\A(?:[^/]|[^/]*/[^/]*\z)}i, true)
                    ), PathList::Matchers::PathRegexp.new(%r{\A[^/]*/[^/]*/c/}i, true)
                 ])
              end

              it 'matches multiple directories when ending with /**/*' do
                expect(build('a/**/*'))
                  .to be_like PathList::Matchers::Any::Two.new([
                    PathList::Matchers::MatchIfDir.new(
                      PathList::Matchers::PathRegexp.new(%r{\Aa(?:\z|/)}i, true)
                    ), PathList::Matchers::PathRegexp.new(%r{\Aa/(?:.*/)?[^/]+/}i, true)
                 ])
              end

              it 'matches multiple directories when ending with **/*' do
                expect(build('a**/*'))
                  .to be_like PathList::Matchers::Any::Two.new([
                    PathList::Matchers::MatchIfDir.new(
                      PathList::Matchers::PathRegexp.new(/\Aa/i, true)
                    ),
                    PathList::Matchers::PathRegexp.new(%r{\Aa(?:.*/)?[^/]+/}i, true)
                 ])
              end

              it 'matches multiple directories when beginning with **/*/' do
                expect(build('**/*/c'))
                  .to be_like PathList::Matchers::Any::Two.new([
                    PathList::Matchers::AllowAnyDir,
                    PathList::Matchers::PathRegexp.new(%r{/c/}i, true)
                 ])
              end

              it 'matches multiple directories when beginning with **/*' do
                expect(build('**/*c'))
                  .to be_like PathList::Matchers::Any::Two.new([
                    PathList::Matchers::AllowAnyDir,
                    PathList::Matchers::PathRegexp.new(%r{c/}i, true)
                 ])
              end
            end
          end

          describe '"?" matches any one character except "/"' do
            it "matches one character at the beginning if there's a ?" do
              expect(build('?our'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)[^/]our/}i, true)
               ])
            end

            it "doesn't match a slash" do
              expect(build('fa?our'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)fa[^/]our/}i, true)
               ])
            end

            it 'matches per ?' do
              expect(build('f??r'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)f[^/][^/]r/}i, true)
               ])
            end

            it "matches a single character at the end if there's a ?" do
              expect(build('fou?'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)fou[^/]/}i, true)
               ])
            end
          end

          describe '"[]" matches one character in a selected range' do
            it 'matches a single character in a character class' do
              expect(build('a[ab]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[ab]/}i, true)
               ])
            end

            it 'matches a single character in a character class range' do
              expect(build('a[a-c]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[a-c]/}i, true)
               ])
            end

            it 'treats a backward character class range as only the first character of the range' do
              expect(build('a[d-a]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[d]/}i, true)
               ])
            end

            it 'treats a negated backward character class range as only the first character of the range' do
              expect(build('a[^d-a]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^d]/}i, true)
               ])
            end

            it 'treats a escaped backward character class range as only the first character of the range' do
              expect(build('a[\\]-\\[]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[\]]/}i, true)
               ])
            end

            it 'treats a negated escaped backward character class range as only the first character of the range' do
              expect(build('a[^\\]-\\[]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^\]]/}i, true)
               ])
            end

            it 'treats a escaped character class range as as a range' do
              expect(build('a[\\[-\\]]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[\[-\]]/}i, true)
               ])
            end

            it 'treats a negated escaped character class range as a range' do
              expect(build('a[^\\[-\\]]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^\[-\]]/}i, true)
               ])
            end

            it 'treats an unnecessarily escaped character class range as a range' do
              expect(build('a[\\a-\\c]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[a-c]/}i, true)
               ])
            end

            it 'treats a negated unnecessarily escaped character class range as a range' do
              expect(build('a[^\\a-\\c]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^a-c]/}i, true)
               ])
            end

            it 'treats a backward character class range with other options as only the first character of the range' do
              expect(build('a[d-ba]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[da]/}i, true)
               ])
            end

            it 'treats a negated backward character class range with other chars as the first character of the range' do
              expect(build('a[^d-ba]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^da]/}i, true)
               ])
            end

            it 'treats a backward char class range with other initial options as the first char of the range' do
              expect(build('a[ad-b]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[ad]/}i, true)
               ])
            end

            it 'treats a negated backward char class range with other initial options as the first char of the range' do
              expect(build('a[^ad-b]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^ad]/}i, true)
               ])
            end

            it 'treats a equal character class range as only the first character of the range' do
              expect(build('a[d-d]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[d]/}i, true)
               ])
            end

            it 'treats a negated equal character class range as only the first character of the range' do
              expect(build('a[^d-d]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^d]/}i, true)
               ])
            end

            it 'interprets a / after a character class range as not there' do
              expect(build('a[a-c/]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[a-c/]/}i, true)
               ])
            end

            it 'interprets a / before a character class range as not there' do
              expect(build('a[/a-c]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[/a-c]/}i, true)
               ])
            end

            # TODO: confirm if that matches a slash character
            it 'interprets a / before the dash in a character class range as any character from / to c' do
              expect(build('a[+/-c]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[\+/-c]/}i, true)
               ])
            end

            it 'interprets a / after the dash in a character class range as any character from start to /' do
              expect(build('a["-/c]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)["-/c]/}i, true)
               ])
            end

            it 'interprets a slash then dash then character to be a character range' do
              expect(build('a[/-c]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[/-c]/}i, true)
               ])
            end

            it 'interprets a character then dash then slash to be a character range' do
              expect(build('a["-/]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)["-/]/}i, true)
               ])
            end

            context 'without raising warnings' do
              # these edge cases raise warnings
              # they're edge-casey enough if you hit them you deserve warnings.
              before { allow(Warning).to receive(:warn) }

              it 'interprets dash dash character as a character range beginning with -' do
                expect(build('a[--c]'))
                  .to be_like PathList::Matchers::Any::Two.new([
                    PathList::Matchers::AllowAnyDir,
                    PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[\--c]/}i, true)
                 ])
              end

              it 'interprets character dash dash as a character range ending with -' do
                expect(build('a["--]'))
                  .to be_like PathList::Matchers::Any::Two.new([
                    PathList::Matchers::AllowAnyDir,
                    PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)["-\-]/}i, true)
                 ])
              end

              it 'interprets dash dash dash as a character range of only with -' do
                expect(build('a[---]'))
                  .to be_like PathList::Matchers::Any::Two.new([
                    PathList::Matchers::AllowAnyDir,
                    PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[\-]/}i, true)
                 ])
              end

              it 'interprets character dash dash dash as a character range of only with " to - with literal -' do
                expect(build('a["---]'))
                  .to be_like PathList::Matchers::Any::Two.new([
                    PathList::Matchers::AllowAnyDir,
                    PathList::Matchers::PathRegexp.new(
                      Regexp.new('(?:\\A|\/)a(?!\/)["-\\-\\-]\/', 1), true
                   )
                 ])
              end

              it 'interprets dash dash dash character as a character range of only - with literal c' do
                expect(build('a[---c]'))
                  .to be_like PathList::Matchers::Any::Two.new([
                    PathList::Matchers::AllowAnyDir,
                    PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[\-c]/}i, true)
                 ])
              end

              it 'interprets character dash dash character as a character range ending with - and a literal c' do
                # this could just as easily be interpreted the other way around (" is the literal, --c is the range),
                # but ruby regex and git seem to treat this edge case the same
                expect(build('a["--c]'))
                  .to be_like PathList::Matchers::Any::Two.new([
                    PathList::Matchers::AllowAnyDir,
                    PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)["-\-c]/}i, true)
                 ])
              end
            end

            it '^ is not' do
              expect(build('a[^a-c]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^a-c]/}i, true)
               ])
            end

            # this doesn't appear to be documented anywhere i just stumbled onto it
            it '! is also not' do
              expect(build('a[!a-c]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^a-c]/}i, true)
               ])
            end

            it '[^/] matches everything' do
              expect(build('a[^/]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^/]/}i, true)
               ])
            end

            it '[^^] matches everything except literal ^' do
              expect(build('a[^^]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^\^]/}i, true)
               ])
            end

            it '[^/a] matches everything except a' do
              expect(build('a[^/a]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[^/a]/}i, true)
               ])
            end

            it '[/^a] matches literal ^ and a' do
              expect(build('a[/^a]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[/\^a]/}i, true)
               ])
            end

            it '[/^] matches literal ^' do
              expect(build('a[/^]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[/\^]/}i, true)
               ])
            end

            it '[\\^] matches literal ^' do
              expect(build('a[\^]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[\^]/}i, true)
               ])
            end

            it 'later ^ is literal' do
              expect(build('a[a-c^]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[a-c\^]/}i, true)
               ])
            end

            it "doesn't match a slash even if you specify it last" do
              expect(build('b[i/]b'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)b(?!/)[i/]b/}i, true)
               ])
            end

            it "doesn't match a slash even if you specify it alone" do
              expect(build('b[/]b'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)b(?!/)[/]b/}i, true)
               ])
            end

            it 'empty class matches nothing' do
              expect(build('b[]b'))
                .to be_like PathList::Matchers::Invalid
            end

            it "doesn't match a slash even if you specify it middle" do
              expect(build('b[i/a]b'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)b(?!/)[i/a]b/}i, true)
               ])
            end

            it "doesn't match a slash even if you specify it start" do
              expect(build('b[/ai]b'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)b(?!/)[/ai]b/}i, true)
               ])
            end

            it 'assumes an unfinished [ matches nothing' do
              expect(build('a['))
                .to be_like PathList::Matchers::Invalid
            end

            it 'assumes an unfinished [ followed by \ matches nothing' do
              expect(build('a[\\'))
                .to be_like PathList::Matchers::Invalid
            end

            it 'assumes an escaped [ is literal' do
              expect(build('a\\['))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a\[/}i, true)
               ])
            end

            it 'assumes an escaped [ is literal inside a group' do
              expect(build('a[\\[]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)a(?!/)[\[]/}i, true)
               ])
            end

            it 'assumes an unfinished [ matches nothing when negated' do
              # nothing matches anything for implicit when negated.
              expect(build('!a['))
                .to be_like PathList::Matchers::Blank
            end

            it 'assumes an unfinished [bc matches nothing' do
              expect(build('a[bc'))
                .to be_like PathList::Matchers::Invalid
            end
          end

          # See fnmatch(3) and the FNM_PATHNAME flag for a more detailed description
        end

        describe 'A leading slash matches the beginning of the pathname.' do
          # For example, "/*.c" matches "cat-file.c" but not "mozilla-sha1/sha1.c".
          it 'matches only at the beginning of everything' do
            expect(build('/*.c'))
              .to be_like PathList::Matchers::PathRegexp.new(%r{\A[^/]*\.c/}i, true)
          end
        end

        describe 'Two consecutive asterisks ("**") in patterns matched against full pathname has a special meaning:' do
          describe 'A leading "**" followed by a slash means match in all directories.' do
            # 'For example, "**/foo" matches file or directory "foo" anywhere, the same as pattern "foo".
            # "**/foo/bar" matches file or directory "bar" anywhere that is directly under directory "foo".'

            it 'matches files or directories in all directories' do
              expect(build('**/foo'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo/}i, true)
               ])
            end

            it 'matches nothing with double slash' do
              expect(build('**//foo'))
                .to be_like PathList::Matchers::Invalid
            end

            it 'matches all directories when only **/ (interpreted as ** then the trailing / for dir only)' do
              expect(build('**/'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{/}i, true)
               ])
            end

            it 'matches files or directories in all directories when repeated' do
              expect(build('**/**/foo'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo/}i, true)
               ])
            end

            it 'matches files or directories in all directories with **/*' do
              expect(build('**/*'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{[^/]/}i, true)
               ])
            end

            it 'matches files or directories in all directories when also followed by a star before text' do
              expect(build('**/*foo'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{foo/}i, true)
               ])
            end

            it 'matches files or directories in all directories when also followed by a star within text' do
              expect(build('**/f*o'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)f[^/]*o/}i, true)
               ])
            end

            it 'matches files or directories in all directories when also followed by a star after text' do
              expect(build('**/fo*'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)fo[^/]*/}i, true)
               ])
            end

            it 'matches files or directories in all directories when three stars' do
              expect(build('***/foo'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::AllowAnyDir,
                  PathList::Matchers::PathRegexp.new(%r{(?:\A|/)foo/}i, true)
               ])
            end
          end

          describe 'A trailing "/**" matches everything inside relative to the location of the .gitignore file.' do
            it 'matches files or directories inside the mentioned directory' do
              expect(build('abc/**'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(/\Aabc\z/i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\Aabc/}i, true)
               ])
            end

            it 'matches all directories inside the mentioned directory' do
              expect(build('abc/**/'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(/\Aabc\z/i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\Aabc/[^/]*/}i, true)
               ])
            end

            it 'matches files or directories inside the mentioned directory when ***' do
              expect(build('abc/***'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(/\Aabc\z/i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\Aabc/}i, true)
               ])
            end
          end

          describe 'A slash followed by two consecutive asterisks then a slash matches zero or more directories.' do
            it 'matches multiple intermediate dirs' do
              expect(build('a/**/b'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\Aa(?:\z|/)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\Aa/(?:.*/)?b/}i, true)
               ])
            end

            it 'matches multiple intermediate dirs with multiple consecutive-asterisk-slashes' do
              expect(build('a/**/b/**/c/**/d'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\Aa(?:\z|/)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\Aa/(?:.*/)?b/(?:.*/)?c/(?:.*/)?d/}i, true)
               ])
            end

            it 'matches multiple intermediate dirs when ***' do
              expect(build('a/***/b'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\Aa(?:\z|/)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\Aa/(?:.*/)?b/}i, true)
               ])
            end
          end

          describe 'Other consecutive asterisks are considered regular asterisks' do
            describe 'and will match according to the previous rules' do
              context 'with two stars' do
                it 'matches any number of characters at the beginning' do
                  expect(build('**our'))
                    .to be_like PathList::Matchers::Any::Two.new([
                      PathList::Matchers::AllowAnyDir,
                      PathList::Matchers::PathRegexp.new(%r{our/}i, true)
                   ])
                end

                it "doesn't match a slash" do
                  expect(build('f**our'))
                    .to be_like PathList::Matchers::Any::Two.new([
                      PathList::Matchers::AllowAnyDir,
                      PathList::Matchers::PathRegexp.new(%r{(?:\A|/)f[^/]*our/}i, true)
                   ])
                end

                it 'matches any number of characters in the middle' do
                  expect(build('f**r'))
                    .to be_like PathList::Matchers::Any::Two.new([
                      PathList::Matchers::AllowAnyDir,
                      PathList::Matchers::PathRegexp.new(%r{(?:\A|/)f[^/]*r/}i, true)
                   ])
                end

                it 'matches any number of characters at the end' do
                  expect(build('few**'))
                    .to be_like PathList::Matchers::Any::Two.new([
                      PathList::Matchers::AllowAnyDir,
                      PathList::Matchers::PathRegexp.new(%r{(?:\A|/)few[^/]*/}i, true)
                   ])
                end

                # not sure if this is a bug but this is git behaviour
                it 'matches any number of directories including none, when following a character, and anchors' do
                  expect(build('f**/our'))
                    .to be_like PathList::Matchers::Any::Two.new([
                      PathList::Matchers::MatchIfDir.new(
                        PathList::Matchers::PathRegexp.new(/\Af/i, true)
                      ),
                      PathList::Matchers::PathRegexp.new(%r{\Af(?:.*/)?our/}i, true)
                   ])
                end
              end
            end
          end
        end
      end
    end

    describe 'allow: true, root: "/a/path"' do
      let(:options) { { allow: true, root: "/a/path" } }

      describe 'from the gitignore documentation' do
        describe 'A blank line matches no files, so it can serve as a separator for readability.' do
          it { expect(build('')).to be_like PathList::Matchers::Blank }
          it { expect(build(' ')).to be_like PathList::Matchers::Blank }
          it { expect(build("\t")).to be_like PathList::Matchers::Blank }
        end

        describe 'The simple case' do
          it 'matches that filename at every level' do
            expect(build('foo')).to be_like PathList::Matchers::Any::Two.new([
              PathList::Matchers::MatchIfDir.new(
                PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
              ),
              PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?foo/}i, true)
           ])
          end
        end

        describe 'A line starting with # serves as a comment.' do
          it { expect(build('#foo')).to be_like PathList::Matchers::Blank }
          it { expect(build('# foo')).to be_like PathList::Matchers::Blank }
          it { expect(build('#')).to be_like PathList::Matchers::Blank }

          it 'must be the first character' do
            expect(build(' #foo'))
              .to be_like PathList::Matchers::Any::Two.new([
                PathList::Matchers::MatchIfDir.new(
                  PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                ),
                PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?\ \#foo/}i, true)
             ])
          end

          describe 'Put a backslash ("\") in front of the first hash for patterns that begin with a hash' do
            it do
              expect(build('\\#foo'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?\#foo/}i, true)
               ])
            end
          end
        end

        describe 'literal backslashes in filenames' do
          it 'matches an escaped backslash at the end of the pattern' do
            expect(build('foo\\\\'))
              .to be_like PathList::Matchers::Any::Two.new([
                PathList::Matchers::MatchIfDir.new(
                  PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                ),
                PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?foo\\/}i, true)
             ])
          end

          it 'never matches a literal backslash at the end of the pattern' do
            expect(build('foo\\'))
              .to be_like PathList::Matchers::Invalid
          end

          it 'matches an escaped backslash at the start of the pattern' do
            expect(build('\\\\foo'))
              .to be_like PathList::Matchers::Any::Two.new([
                PathList::Matchers::MatchIfDir.new(
                  PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                ),
                PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?\\foo/}i, true)
             ])
          end

          it 'matches a literal escaped f at the start of the pattern' do
            expect(build('\\foo'))
              .to be_like PathList::Matchers::Any::Two.new([
                PathList::Matchers::MatchIfDir.new(
                  PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                ),
                PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?foo/}i, true)
             ])
          end
        end

        describe 'Trailing spaces are ignored unless they are quoted with backslash ("\")' do
          it 'ignores trailing spaces in the gitignore file' do
            expect(build('foo  '))
              .to be_like PathList::Matchers::Any::Two.new([
                PathList::Matchers::MatchIfDir.new(
                  PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                ),
                PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?foo/}i, true)
             ])
          end

          it "doesn't ignore trailing spaces if there's a backslash" do
            expect(build('foo \\ '))
              .to be_like PathList::Matchers::Any::Two.new([
                PathList::Matchers::MatchIfDir.new(
                  PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                ),
                PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?foo\ \ /}i, true)
             ])
          end

          it 'considers trailing backslashes to never be matched' do
            expect(build('foo\\'))
              .to be_like PathList::Matchers::Invalid
          end

          it "doesn't ignore trailing spaces if there's a backslash before every space" do
            expect(build('foo\\ \\ '))
              .to be_like PathList::Matchers::Any::Two.new([
                PathList::Matchers::MatchIfDir.new(
                  PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                ),
                PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?foo\ \ /}i, true)
             ])
          end

          it "doesn't ignore just that trailing spaces if there's a backslash before the non last space" do
            expect(build('foo\\  '))
              .to be_like PathList::Matchers::Any::Two.new([
                PathList::Matchers::MatchIfDir.new(
                  PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                ),
                PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?foo\ /}i, true)
             ])
          end
        end

        describe 'If the pattern ends with a slash, it is removed for the purpose of the following description' do
          describe 'but it would only find a match with a directory' do
            # In other words, foo/ will match a directory foo and paths underneath it,
            # but will not match a regular file or a symbolic link foo
            # (this is consistent with the way how pathspec works in general in Git).

            it 'ignores directories but not files or symbolic links that match patterns ending with /' do
              expect(build('foo/'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?foo/}i, true)
               ])
            end

            it 'handles this specific edge case i stumbled across' do
              expect(build('Ȋ/'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?Ȋ/}i, true)
               ])
            end
          end
        end

        # The slash / is used as the directory separator.
        # Separators may occur at the beginning, middle or end of the .gitignore search pattern.
        describe 'If there is a separator at the beginning or middle (or both) of the pattern' do
          describe 'then the pattern is relative to the directory level of the particular .gitignore file itself.' do
            # For example, a pattern doc/frotz/ matches doc/frotz directory, but not a/doc/frotz directory;
            # The pattern doc/frotz and /doc/frotz have the same effect in any .gitignore file.
            # In other words, a leading slash is not relevant if there is already a middle slash in the pattern.
            it 'includes files relative to the git dir with a middle slash' do
              expect(build('doc/frotz'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/doc\z|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A/a/path/doc/frotz/}i, true)
               ])
            end

            it 'treats a double slash as matching nothing' do
              expect(build('doc//frotz'))
                .to be_like PathList::Matchers::Invalid
            end
          end

          describe 'Otherwise the pattern may also match at any level below the .gitignore level.' do
            # frotz/ matches frotz and a/frotz that is a directory

            it 'includes files relative to anywhere with only an end slash' do
              expect(build('frotz/'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?frotz/}i, true)
               ])
            end

            it 'strips trailing space before deciding a rule is dir_only' do
              expect(build('frotz/ '))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?frotz/}i, true)
               ])
            end
          end
        end

        describe 'An optional prefix "!" which negates the pattern' do
          describe 'any matching file excluded by a previous pattern will become included again.' do
            it 'includes previously excluded files' do
              expect(build('!foo'))
                .to be_like PathList::Matchers::Blank
            end
          end

          describe 'Put a backslash ("\") in front of the first "!" for patterns that begin with a literal "!"' do
            # for example, "\!important!.txt".'

            it 'matches files starting with a literal ! if its preceded by a backslash' do
              expect(build('\!important!.txt'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?!important!\.txt/}i, true)
               ])
            end
          end
        end

        describe 'Otherwise, Git treats the pattern as a shell glob' do
          describe '"*" matches anything except "/"' do
            describe 'single level' do
              it "matches any number of characters at the beginning if there's a star" do
                expect(build('*our'))
                  .to be_like PathList::Matchers::Any::Two.new([
                    PathList::Matchers::MatchIfDir.new(
                      PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                    ),
                    PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/.*our/}i, true)
                 ])
              end

              it "matches any number of characters at the beginning if there's a star followed by a slash" do
                expect(build('*/our'))
                  .to be_like PathList::Matchers::Any::Two.new([
                    PathList::Matchers::MatchIfDir.new(
                      PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/[^/]*\z|\z)|\z)|\z)}i, true)
                    ),
                    PathList::Matchers::PathRegexp.new(%r{\A/a/path/[^/]*/our/}i, true)
                 ])
              end

              it "doesn't match a slash" do
                expect(build('f*our'))
                  .to be_like PathList::Matchers::Any::Two.new([
                    PathList::Matchers::MatchIfDir.new(
                      PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                    ),
                    PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?f[^/]*our/}i, true)
                 ])
              end

              it "matches any number of characters in the middle if there's a star" do
                expect(build('f*r'))
                  .to be_like PathList::Matchers::Any::Two.new([
                    PathList::Matchers::MatchIfDir.new(
                      PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                    ),
                    PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?f[^/]*r/}i, true)
                 ])
              end

              it "matches any number of characters at the end if there's a star" do
                expect(build('few*'))
                  .to be_like PathList::Matchers::Any::Two.new([
                    PathList::Matchers::MatchIfDir.new(
                      PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                    ),
                    PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?few[^/]*/}i, true)
                 ])
              end
            end

            describe 'multi level' do
              it 'matches a whole directory' do
                expect(build('a/*/c'))
                  .to be_like PathList::Matchers::Any::Two.new([
                    PathList::Matchers::MatchIfDir.new(
                      PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/a(?:/[^/]*\z|\z)|\z)|\z)|\z)}i, true)
                    ),
                    PathList::Matchers::PathRegexp.new(%r{\A/a/path/a/[^/]*/c/}i, true)
                 ])
              end

              it 'matches an exact partial match at start' do
                expect(build('a/b*/c'))
                  .to be_like PathList::Matchers::Any::Two.new([
                    PathList::Matchers::MatchIfDir.new(
                      PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/a(?:/b[^/]*\z|\z)|\z)|\z)|\z)}i, true)
                    ),
                    PathList::Matchers::PathRegexp.new(%r{\A/a/path/a/b[^/]*/c/}i, true)
                 ])
              end

              it 'matches an exact partial match at end' do
                expect(build('a/*b/c'))
                  .to be_like PathList::Matchers::Any::Two.new([
                    PathList::Matchers::MatchIfDir.new(
                      PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/a(?:/[^/]*b\z|\z)|\z)|\z)|\z)}i, true)
                    ),
                    PathList::Matchers::PathRegexp.new(%r{\A/a/path/a/[^/]*b/c/}i, true)
                 ])
              end

              it 'matches multiple directories when sequential /*/' do
                expect(build('a/*/*'))
                  .to be_like PathList::Matchers::Any::Two.new([
                    PathList::Matchers::MatchIfDir.new(
                      PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/a(?:/[^/]*\z|\z)|\z)|\z)|\z)}i, true)
                    ),
                    PathList::Matchers::PathRegexp.new(%r{\A/a/path/a/[^/]*/[^/]*/}i, true)
                 ])
              end

              it 'matches multiple directories when beginning sequential /*/' do
                expect(build('*/*/c'))
                  .to be_like PathList::Matchers::Any::Two.new([
                    PathList::Matchers::MatchIfDir.new(
                      PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/[^/]*(?:/[^/]*\z|\z)|\z)|\z)|\z)}i, true)
                    ), PathList::Matchers::PathRegexp.new(%r{\A/a/path/[^/]*/[^/]*/c/}i, true)
                 ])
              end

              it 'matches multiple directories when ending with /**/*' do
                expect(build('a/**/*'))
                  .to be_like PathList::Matchers::Any::Two.new([
                    PathList::Matchers::MatchIfDir.new(
                      PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/a(?:/|\z)|\z)|\z)|\z)}i, true)
                    ), PathList::Matchers::PathRegexp.new(%r{\A/a/path/a/.*/}i, true)
                 ])
              end

              it 'matches multiple directories when ending with **/*' do
                expect(build('a**/*'))
                  .to be_like PathList::Matchers::Any::Two.new([
                    PathList::Matchers::MatchIfDir.new(
                      PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/a|\z)|\z)|\z)}i, true)
                    ),
                    PathList::Matchers::PathRegexp.new(%r{\A/a/path/a.*/}i, true)
                 ])
              end

              it 'matches multiple directories when beginning with **/*/' do
                expect(build('**/*/c'))
                  .to be_like PathList::Matchers::Any::Two.new([
                    PathList::Matchers::MatchIfDir.new(
                      PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                    ),
                    PathList::Matchers::PathRegexp.new(%r{\A/a/path/.*/c/}i, true)
                 ])
              end

              it 'matches multiple directories when beginning with **/*' do
                expect(build('**/*c'))
                  .to be_like PathList::Matchers::Any::Two.new([
                    PathList::Matchers::MatchIfDir.new(
                      PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                    ),
                    PathList::Matchers::PathRegexp.new(%r{\A/a/path/.*c/}i, true)
                 ])
              end
            end
          end

          describe '"?" matches any one character except "/"' do
            it "matches one character at the beginning if there's a ?" do
              expect(build('?our'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?[^/]our/}i, true)
               ])
            end

            it "doesn't match a slash" do
              expect(build('fa?our'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?fa[^/]our/}i, true)
               ])
            end

            it 'matches per ?' do
              expect(build('f??r'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?f[^/][^/]r/}i, true)
               ])
            end

            it "matches a single character at the end if there's a ?" do
              expect(build('fou?'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?fou[^/]/}i, true)
               ])
            end
          end

          describe '"[]" matches one character in a selected range' do
            it 'matches a single character in a character class' do
              expect(build('a[ab]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[ab]/}i, true)
               ])
            end

            it 'matches a single character in a character class range' do
              expect(build('a[a-c]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[a-c]/}i, true)
               ])
            end

            it 'treats a backward character class range as only the first character of the range' do
              expect(build('a[d-a]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[d]/}i, true)
               ])
            end

            it 'treats a negated backward character class range as only the first character of the range' do
              expect(build('a[^d-a]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[^d]/}i, true)
               ])
            end

            it 'treats a escaped backward character class range as only the first character of the range' do
              expect(build('a[\\]-\\[]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[\]]/}i, true)
               ])
            end

            it 'treats a negated escaped backward character class range as only the first character of the range' do
              expect(build('a[^\\]-\\[]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[^\]]/}i, true)
               ])
            end

            it 'treats a escaped character class range as as a range' do
              expect(build('a[\\[-\\]]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[\[-\]]/}i, true)
               ])
            end

            it 'treats a negated escaped character class range as a range' do
              expect(build('a[^\\[-\\]]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[^\[-\]]/}i, true)
               ])
            end

            it 'treats an unnecessarily escaped character class range as a range' do
              expect(build('a[\\a-\\c]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[a-c]/}i, true)
               ])
            end

            it 'treats a negated unnecessarily escaped character class range as a range' do
              expect(build('a[^\\a-\\c]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[^a-c]/}i, true)
               ])
            end

            it 'treats a backward character class range with other options as only the first character of the range' do
              expect(build('a[d-ba]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[da]/}i, true)
               ])
            end

            it 'treats a negated backward character class range with other chars as the first character of the range' do
              expect(build('a[^d-ba]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[^da]/}i, true)
               ])
            end

            it 'treats a backward char class range with other initial options as the first char of the range' do
              expect(build('a[ad-b]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[ad]/}i, true)
               ])
            end

            it 'treats a negated backward char class range with other initial options as the first char of the range' do
              expect(build('a[^ad-b]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[^ad]/}i, true)
               ])
            end

            it 'treats a equal character class range as only the first character of the range' do
              expect(build('a[d-d]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[d]/}i, true)
               ])
            end

            it 'treats a negated equal character class range as only the first character of the range' do
              expect(build('a[^d-d]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[^d]/}i, true)
               ])
            end

            it 'interprets a / after a character class range as not there' do
              expect(build('a[a-c/]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[a-c/]/}i, true)
               ])
            end

            it 'interprets a / before a character class range as not there' do
              expect(build('a[/a-c]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[/a-c]/}i, true)
               ])
            end

            # TODO: confirm if that matches a slash character
            it 'interprets a / before the dash in a character class range as any character from / to c' do
              expect(build('a[+/-c]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[\+/-c]/}i, true)
               ])
            end

            it 'interprets a / after the dash in a character class range as any character from start to /' do
              expect(build('a["-/c]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)["-/c]/}i, true)
               ])
            end

            it 'interprets a slash then dash then character to be a character range' do
              expect(build('a[/-c]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[/-c]/}i, true)
               ])
            end

            it 'interprets a character then dash then slash to be a character range' do
              expect(build('a["-/]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)["-/]/}i, true)
               ])
            end

            context 'without raising warnings' do
              # these edge cases raise warnings
              # they're edge-casey enough if you hit them you deserve warnings.
              before { allow(Warning).to receive(:warn) }

              it 'interprets dash dash character as a character range beginning with -' do
                expect(build('a[--c]'))
                  .to be_like PathList::Matchers::Any::Two.new([
                    PathList::Matchers::MatchIfDir.new(
                      PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                    ),
                    PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[\--c]/}i, true)
                 ])
              end

              it 'interprets character dash dash as a character range ending with -' do
                expect(build('a["--]'))
                  .to be_like PathList::Matchers::Any::Two.new([
                    PathList::Matchers::MatchIfDir.new(
                      PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                    ),
                    PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)["-\-]/}i, true)
                 ])
              end

              it 'interprets dash dash dash as a character range of only with -' do
                expect(build('a[---]'))
                  .to be_like PathList::Matchers::Any::Two.new([
                    PathList::Matchers::MatchIfDir.new(
                      PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                    ),
                    PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[\-]/}i, true)
                 ])
              end

              it 'interprets character dash dash dash as a character range of only with " to - with literal -' do
                expect(build('a["---]'))
                  .to be_like PathList::Matchers::Any::Two.new([
                    PathList::Matchers::MatchIfDir.new(
                      PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                    ),
                    PathList::Matchers::PathRegexp.new(
                      Regexp.new('\\A/a/path/(?:.*/)?a(?!/)["-\\-\\-]/', 1), true
                   )
                 ])
              end

              it 'interprets dash dash dash character as a character range of only - with literal c' do
                expect(build('a[---c]'))
                  .to be_like PathList::Matchers::Any::Two.new([
                    PathList::Matchers::MatchIfDir.new(
                      PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                    ),
                    PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[\-c]/}i, true)
                 ])
              end

              it 'interprets character dash dash character as a character range ending with - and a literal c' do
                # this could just as easily be interpreted the other way around (" is the literal, --c is the range),
                # but ruby regex and git seem to treat this edge case the same
                expect(build('a["--c]'))
                  .to be_like PathList::Matchers::Any::Two.new([
                    PathList::Matchers::MatchIfDir.new(
                      PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                    ),
                    PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)["-\-c]/}i, true)
                 ])
              end
            end

            it '^ is not' do
              expect(build('a[^a-c]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[^a-c]/}i, true)
               ])
            end

            # this doesn't appear to be documented anywhere i just stumbled onto it
            it '! is also not' do
              expect(build('a[!a-c]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[^a-c]/}i, true)
               ])
            end

            it '[^/] matches everything' do
              expect(build('a[^/]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[^/]/}i, true)
               ])
            end

            it '[^^] matches everything except literal ^' do
              expect(build('a[^^]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[^\^]/}i, true)
               ])
            end

            it '[^/a] matches everything except a' do
              expect(build('a[^/a]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[^/a]/}i, true)
               ])
            end

            it '[/^a] matches literal ^ and a' do
              expect(build('a[/^a]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[/\^a]/}i, true)
               ])
            end

            it '[/^] matches literal ^' do
              expect(build('a[/^]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[/\^]/}i, true)
               ])
            end

            it '[\\^] matches literal ^' do
              expect(build('a[\^]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[\^]/}i, true)
               ])
            end

            it 'later ^ is literal' do
              expect(build('a[a-c^]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[a-c\^]/}i, true)
               ])
            end

            it "doesn't match a slash even if you specify it last" do
              expect(build('b[i/]b'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?b(?!/)[i/]b/}i, true)
               ])
            end

            it "doesn't match a slash even if you specify it alone" do
              expect(build('b[/]b'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?b(?!/)[/]b/}i, true)
               ])
            end

            it 'empty class matches nothing' do
              expect(build('b[]b'))
                .to be_like PathList::Matchers::Invalid
            end

            it "doesn't match a slash even if you specify it middle" do
              expect(build('b[i/a]b'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?b(?!/)[i/a]b/}i, true)
               ])
            end

            it "doesn't match a slash even if you specify it start" do
              expect(build('b[/ai]b'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?b(?!/)[/ai]b/}i, true)
               ])
            end

            it 'assumes an unfinished [ matches nothing' do
              expect(build('a['))
                .to be_like PathList::Matchers::Invalid
            end

            it 'assumes an unfinished [ followed by \ matches nothing' do
              expect(build('a[\\'))
                .to be_like PathList::Matchers::Invalid
            end

            it 'assumes an escaped [ is literal' do
              expect(build('a\\['))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a\[/}i, true)
               ])
            end

            it 'assumes an escaped [ is literal inside a group' do
              expect(build('a[\\[]'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?a(?!/)[\[]/}i, true)
               ])
            end

            it 'assumes an unfinished [ matches nothing when negated' do
              # nothing matches anything for implicit when negated.
              expect(build('!a['))
                .to be_like PathList::Matchers::Blank
            end

            it 'assumes an unfinished [bc matches nothing' do
              expect(build('a[bc'))
                .to be_like PathList::Matchers::Invalid
            end
          end

          # See fnmatch(3) and the FNM_PATHNAME flag for a more detailed description
        end

        describe 'A leading slash matches the beginning of the pathname.' do
          # For example, "/*.c" matches "cat-file.c" but not "mozilla-sha1/sha1.c".
          it 'matches only at the beginning of everything' do
            expect(build('/*.c'))
              .to be_like PathList::Matchers::Any::Two.new([
                PathList::Matchers::MatchIfDir.new(
                  PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path\z|\z)|\z)}i, true)
                ),
                PathList::Matchers::PathRegexp.new(%r{\A/a/path/[^/]*\.c/}i, true)
             ])
          end
        end

        describe 'Two consecutive asterisks ("**") in patterns matched against full pathname has a special meaning:' do
          describe 'A leading "**" followed by a slash means match in all directories.' do
            # 'For example, "**/foo" matches file or directory "foo" anywhere, the same as pattern "foo".
            # "**/foo/bar" matches file or directory "bar" anywhere that is directly under directory "foo".'

            it 'matches files or directories in all directories' do
              expect(build('**/foo'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?foo/}i, true)
               ])
            end

            it 'matches nothing with double slash' do
              expect(build('**//foo'))
                .to be_like PathList::Matchers::Invalid
            end

            it 'matches all directories when only **/ (interpreted as ** then the trailing / for dir only)' do
              expect(build('**/'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A/a/path/.*/}i, true)
               ])
            end

            it 'matches files or directories in all directories when repeated' do
              expect(build('**/**/foo'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?foo/}i, true)
               ])
            end

            it 'matches files or directories in all directories with **/*' do
              expect(build('**/*'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A/a/path/.*/}i, true)
               ])
            end

            it 'matches files or directories in all directories when also followed by a star before text' do
              expect(build('**/*foo'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A/a/path/.*foo/}i, true)
               ])
            end

            it 'matches files or directories in all directories when also followed by a star within text' do
              expect(build('**/f*o'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?f[^/]*o/}i, true)
               ])
            end

            it 'matches files or directories in all directories when also followed by a star after text' do
              expect(build('**/fo*'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?fo[^/]*/}i, true)
               ])
            end

            it 'matches files or directories in all directories when three stars' do
              expect(build('***/foo'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?foo/}i, true)
               ])
            end
          end

          describe 'A trailing "/**" matches everything inside relative to the location of the .gitignore file.' do
            it 'matches files or directories inside the mentioned directory' do
              expect(build('abc/**'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/abc\z|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A/a/path/abc/.*\/}i, true)
               ])
            end

            it 'matches all directories inside the mentioned directory' do
              expect(build('abc/**/'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/abc\z|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A/a/path/abc/.*/}i, true)
               ])
            end

            it 'matches files or directories inside the mentioned directory when ***' do
              expect(build('abc/***'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/abc\z|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A/a/path/abc/.*/}i, true)
               ])
            end
          end

          describe 'A slash followed by two consecutive asterisks then a slash matches zero or more directories.' do
            it 'matches multiple intermediate dirs' do
              expect(build('a/**/b'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/a(?:/|\z)|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A/a/path/a/(?:.*/)?b/}i, true)
               ])
            end

            it 'matches multiple intermediate dirs with multiple consecutive-asterisk-slashes' do
              expect(build('a/**/b/**/c/**/d'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/a(?:/|\z)|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A/a/path/a/(?:.*/)?b/(?:.*/)?c/(?:.*/)?d/}i, true)
               ])
            end

            it 'matches multiple intermediate dirs when ***' do
              expect(build('a/***/b'))
                .to be_like PathList::Matchers::Any::Two.new([
                  PathList::Matchers::MatchIfDir.new(
                    PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/a(?:/|\z)|\z)|\z)|\z)}i, true)
                  ),
                  PathList::Matchers::PathRegexp.new(%r{\A/a/path/a/(?:.*/)?b/}i, true)
               ])
            end
          end

          describe 'Other consecutive asterisks are considered regular asterisks' do
            describe 'and will match according to the previous rules' do
              context 'with two stars' do
                it 'matches any number of characters at the beginning' do
                  expect(build('**our'))
                    .to be_like PathList::Matchers::Any::Two.new([
                      PathList::Matchers::MatchIfDir.new(
                        PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                      ),
                      PathList::Matchers::PathRegexp.new(%r{\A/a/path/.*our/}i, true)
                   ])
                end

                it "doesn't match a slash" do
                  expect(build('f**our'))
                    .to be_like PathList::Matchers::Any::Two.new([
                      PathList::Matchers::MatchIfDir.new(
                        PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                      ),
                      PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?f[^/]*our/}i, true)
                   ])
                end

                it 'matches any number of characters in the middle' do
                  expect(build('f**r'))
                    .to be_like PathList::Matchers::Any::Two.new([
                      PathList::Matchers::MatchIfDir.new(
                        PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                      ),
                      PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?f[^/]*r/}i, true)
                   ])
                end

                it 'matches any number of characters at the end' do
                  expect(build('few**'))
                    .to be_like PathList::Matchers::Any::Two.new([
                      PathList::Matchers::MatchIfDir.new(
                        PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/|\z)|\z)|\z)}i, true)
                      ),
                      PathList::Matchers::PathRegexp.new(%r{\A\/a\/path\/(?:.*\/)?few[^/]*/}i, true)
                   ])
                end

                # not sure if this is a bug but this is git behaviour
                it 'matches any number of directories including none, when following a character, and anchors' do
                  expect(build('f**/our'))
                    .to be_like PathList::Matchers::Any::Two.new([
                      PathList::Matchers::MatchIfDir.new(
                        PathList::Matchers::PathRegexp.new(%r{\A/(?:a(?:/path(?:/f|\z)|\z)|\z)}i, true)
                      ),
                      PathList::Matchers::PathRegexp.new(%r{\A/a/path/f(?:.*/)?our/}i, true)
                   ])
                end
              end
            end
          end
        end
      end
    end
  end
end

# rubocop:enable Style/RedundantRegexpEscape
