# frozen_string_literal: true

RSpec.describe PathList do
  subject { described_class.gitignore }

  within_temp_dir

  let(:root) { Dir.pwd }
  let(:gitignore_path) { File.join(root, '.gitignore') }

  shared_examples 'the gitignore documentation' do
    describe 'A blank line matches no files, so it can serve as a separator for readability.' do
      # an empty list matches everything for include rules
      # So this uses allow_files instead of match_files
      it 'matches nothing when gitignore is empty' do
        gitignore

        expect(subject).to allow_files('foo', 'bar', 'baz')
        expect(subject).not_to allow_files('/.gitignore', create: false) # files outside root are not allowed
      end

      # an empty list matches everything for include rules
      # So this uses allow_files instead of match_files
      it 'matches nothing when gitignore only contains newlines' do
        gitignore "\n\n\n"

        expect(subject).to allow_files('foo', 'bar', 'baz')
      end

      it 'matches mentioned files when gitignore includes newlines' do
        gitignore "\n\n\n\n\nfoo\nbar\n\n\n"

        expect(subject).not_to match_files('baz')
        expect(subject).to match_files('foo', 'bar')
      end
    end

    describe 'A line starting with # serves as a comment.' do
      it "doesn't match files whose names look like a comment" do
        gitignore '#foo', 'foo'

        expect(subject).not_to match_files('#foo')
        expect(subject).to match_files('foo')
      end

      describe 'Put a backslash ("\") in front of the first hash for patterns that begin with a hash' do
        it 'ignores files whose names look like a comment when prefixed with a backslash' do
          gitignore '\\#foo'

          expect(subject).not_to match_files('foo')
          expect(subject).to match_files('#foo')
        end
      end
    end

    describe(
      'literal backslashes in filenames',
      skip: ("can't have literal backslashes in filenames in windows" if windows?)
    ) do
      it "never matches backslashes when they're not in the pattern" do
        gitignore 'foo'

        expect(subject).to match_files('foo')
        expect(subject).not_to match_files('foo\\', '\\\\foo', 'foo\\\\', '\\foo', 'fo\\o/\\foo')
      end

      it 'matches an escaped backslash at the end of the pattern' do
        gitignore 'foo\\\\'

        expect(subject).to match_files('foo\\')
        expect(subject).not_to match_files('\\\\foo', 'foo', 'fo\\o/\\foo', 'foo\\\\', '\\foo')
      end

      it 'never matches a literal backslash at the end of the pattern' do
        gitignore 'foo\\'

        expect(subject).not_to match_files('\\\\foo', 'foo\\', 'foo', 'fo\\o/\\foo', 'foo\\\\', '\\foo')
      end

      it 'matches an escaped backslash at the start of the pattern' do
        gitignore '\\\\foo'

        expect(subject).to match_files('\\foo', 'fo\\o/\\foo')
        expect(subject).not_to match_files('\\\\foo', 'foo\\', 'foo', 'foo\\\\')
      end

      it 'matches a literal escaped f at the start of the pattern' do
        gitignore '\\foo'

        expect(subject).not_to match_files('\\\\foo', 'foo\\', 'fo\\o/\\foo', 'foo\\\\', '\\foo')
        expect(subject).to match_files('foo')
      end
    end

    describe(
      'Trailing spaces are ignored unless they are quoted with backslash ("\")',
      skip: ("can't end with literal backslashes in filenames in windows" if windows?)
    ) do
      it 'ignores trailing spaces in the gitignore file' do
        gitignore 'foo  '

        expect(subject).not_to match_files('foo  ', 'foo ', 'foo\\')
        expect(subject).to match_files('foo')
      end

      it "doesn't ignore trailing spaces if there's a backslash" do
        gitignore "foo \\ \n"

        expect(subject).not_to match_files('foo', 'foo ', 'foo\\')
        expect(subject).to match_files('foo  ')
      end

      it 'considers trailing backslashes to never be matched' do
        gitignore "foo\\\n"

        expect(subject).not_to match_files('foo  ', 'foo ', 'foo', 'foo\\')
      end

      it "doesn't ignore trailing spaces if there's a backslash before every space" do
        gitignore "foo\\ \\ \n"

        expect(subject).not_to match_files('foo', 'foo ', 'foo\\')
        expect(subject).to match_files('foo  ')
      end

      it "doesn't ignore just that trailing space if there's a backslash before the non last space" do
        gitignore "foo\\  \n"

        expect(subject).not_to match_files('foo', 'foo  ', 'foo\\')
        expect(subject).to match_files('foo ')
      end
    end

    describe 'If the pattern ends with a slash, it is removed for the purpose of the following description' do
      describe 'but it would only find a match with a directory' do
        # In other words, foo/ will match a directory foo and paths underneath it,
        # but will not match a regular file or a symbolic link foo
        # (this is consistent with the way how pathspec works in general in Git).

        before do
          create_file_list 'bar/foo', 'foo/bar', 'bar/baz'
          create_symlink 'baz/foo' => 'bar'
        end

        it 'ignores directories but not files or symbolic links that match patterns ending with /' do
          gitignore 'foo/'

          expect(subject).not_to match_files('bar/foo', 'baz/foo', 'bar/baz', create: false)
          expect(subject).to match_files('foo/bar', create: false)
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
          gitignore 'doc/frotz'

          expect(subject).to match_files('doc/frotz/b')
          expect(subject).not_to match_files('a/doc/frotz/c', 'd/doc/frotz')
        end

        it 'treats a double slash as matching nothing' do
          gitignore 'doc//frotz'

          expect(subject).not_to match_files('doc/frotz/b', 'a/doc/frotz/c', 'd/doc/frotz')
        end
      end

      describe 'Otherwise the pattern may also match at any level below the .gitignore level.' do
        # frotz/ matches frotz and a/frotz that is a directory

        it 'includes files relative to anywhere with only an end slash' do
          gitignore 'frotz/'

          expect(subject).to match_files('doc/frotz/b', 'a/doc/frotz/c')
          expect(subject).not_to match_files('d/doc/frotz')
        end

        it 'strips trailing space before deciding a rule is dir_only' do
          gitignore 'frotz/ '

          expect(subject).to match_files('doc/frotz/b', 'a/doc/frotz/c')
          expect(subject).not_to match_files('d/doc/frotz')
        end
      end
    end

    describe 'An optional prefix "!" which negates the pattern' do
      describe 'any matching file excluded by a previous pattern will become included again.' do
        it 'includes previously excluded files' do
          gitignore 'fo*', '!foo'

          expect(subject).not_to match_files('foo')
          expect(subject).to match_files('foe')
        end

        it 'is read in order' do
          gitignore '!foo', 'fo*'

          expect(subject).to match_files('foe', 'foo')
        end

        it 'has no effect if not negating anything' do
          gitignore '!foo'

          expect(subject).not_to match_files('foe', 'foo')
        end
      end

      describe 'It is not possible to negate a file if a parent directory of that file is matched' do
        # Git doesn't list excluded directories for performance reasons
        # so any patterns on contained files have no effect no matter where they are defined

        # NOTE: this has different behaviour between includes & ignore.
        # thus the awkwardness with match_files and allow_files.
        # TODO: make include rules match ignore rules behavior.
        it "doesn't negate files inside previously matched directories" do
          gitignore 'foo', '!foo/bar'

          expect(subject).not_to match_files('bar/bar')
          expect(subject).to match_files('foo/foo')
          expect(subject).not_to allow_files('foo/bar')
        end

        it 'does negate files inside previously matched directories/*' do
          gitignore '/foo/*', '!/foo/bar/', '!/foo/baz/'

          expect(subject).not_to match_files('foo/bar/baz', 'bar/bar', 'foo/baz/baz')
          expect(subject).to match_files('foo/foo')
        end

        it 'does negate files inside previously matched directories with exact match before the final star' do
          create_file_list 'foo/ba', 'foo/bar/baz', 'foo/baz/baz', 'foo/foo', 'bar/bar'

          gitignore '/foo/ba*', '!/foo/bar/', '!/foo/baz/'

          expect(subject).not_to match_files('foo/bar/baz', 'bar/bar', 'foo/baz/baz', 'foo/foo')
          expect(subject).to match_files('foo/ba')
        end

        # NOTE: this has different behaviour between includes & ignore.
        # thus the awkwardness with match_files and allow_files.
        # TODO: make include rules match ignore rules behavior.
        it "doesn't negate files inside previously matched directories/**" do
          gitignore '/foo/**', '!/foo/bar/', '!/foo/baz/'

          expect(subject).not_to match_files('bar/bar')
          expect(subject).to match_files('foo/foo')
          expect(subject).not_to allow_files('foo/bar/baz', 'foo/baz/baz')
        end
      end

      describe 'Put a backslash ("\") in front of the first "!" for patterns that begin with a literal "!"' do
        # for example, "\!important!.txt".'

        it 'matches files starting with a literal ! if its preceded by a backslash' do
          gitignore '\!important!.txt'

          expect(subject).not_to match_files('important!.txt')
          expect(subject).to match_files('!important!.txt')
        end
      end
    end

    describe 'Otherwise, Git treats the pattern as a shell glob' do
      describe '"*" matches anything except "/"' do
        describe 'single level' do
          it "matches any number of characters at the beginning if there's a star" do
            gitignore '*our'

            expect(subject).not_to match_files('few', 'fewer')
            expect(subject).to match_files('f/our', 'four', 'favour')
          end

          it "matches any number of characters at the beginning if there's a star followed by a slash" do
            gitignore '*/our'

            expect(subject).not_to match_files('few', 'fewer', 'four', 'favour')
            expect(subject).to match_files('f/our')
          end

          it "doesn't match a slash" do
            gitignore 'f*our'

            expect(subject).not_to match_files('few', 'fewer', 'f/our')
            expect(subject).to match_files('four', 'favour')
          end

          it "matches any number of characters in the middle if there's a star" do
            gitignore 'f*r'

            expect(subject).not_to match_files('f/our', 'few')
            expect(subject).to match_files('four', 'fewer', 'favour')
          end

          it "matches any number of characters at the end if there's a star" do
            gitignore 'few*'

            expect(subject).not_to match_files('f/our', 'four', 'favour')
            expect(subject).to match_files('few', 'fewer')
          end
        end

        describe 'multi level' do
          it 'matches a whole directory' do
            gitignore 'a/*/c'

            expect(subject).to match_files('a/b/c', 'a/c/c')
            expect(subject).not_to match_files('a/b/d', 'a/c/d', 'b/b/c', 'b/b/d', 'b/c/c', 'b/c/d')
          end

          it 'matches an exact partial match at start' do
            gitignore 'a/b*/c'

            expect(subject).to match_files('a/b/c')
            expect(subject).not_to match_files('a/b/d', 'a/c/c', 'a/c/d', 'b/b/c', 'b/b/d', 'b/c/c', 'b/c/d')
          end

          it 'matches an exact partial match at end' do
            gitignore 'a/*b/c'

            expect(subject).to match_files('a/b/c')
            expect(subject).not_to match_files('a/b/d', 'a/c/c', 'a/c/d', 'b/b/c', 'b/b/d', 'b/c/c', 'b/c/d')
          end

          it 'matches multiple directories when sequential /*/' do
            gitignore 'a/*/*'

            expect(subject).to match_files('a/b/c', 'a/b/d', 'a/c/c', 'a/c/d')
            expect(subject).not_to match_files('b/b/c', 'b/b/d', 'b/c/c', 'b/c/d')
          end

          it 'matches multiple directories when beginning sequential /*/' do
            gitignore '*/*/c'

            expect(subject).to match_files('b/b/c', 'a/b/c', 'a/c/c', 'b/c/c')
            expect(subject).not_to match_files('a/b/d', 'a/c/d', 'b/b/d', 'b/c/d')
          end

          it 'matches multiple directories when ending with /**/*/' do
            gitignore 'a/**/*'

            expect(subject).to match_files('a/b/c', 'a/b/d', 'a/c/c', 'a/c/d')
            expect(subject).not_to match_files('b/b/c', 'b/b/d', 'b/c/c', 'b/c/d')
          end

          it 'matches multiple directories when ending with **/*/' do
            gitignore 'a**/*'

            expect(subject).to match_files('a/b/c', 'a/b/d', 'a/c/c', 'a/c/d')
            expect(subject).not_to match_files('b/b/c', 'b/b/d', 'b/c/c', 'b/c/d')
          end

          it 'matches multiple directories when beginning with **/*/' do
            gitignore '**/*/c'

            expect(subject).to match_files('b/b/c', 'a/b/c', 'a/c/c', 'b/c/c', 'a/c/d', 'b/c/d')
            expect(subject).not_to match_files('a/b/d', 'b/b/d')
          end

          it 'matches multiple directories when beginning with **/*' do
            gitignore '**/*c'

            expect(subject).to match_files('b/b/c', 'a/b/c', 'a/c/c', 'b/c/c', 'a/c/d', 'b/c/d')
            expect(subject).not_to match_files('a/b/d', 'b/b/d')
          end
        end
      end

      describe '"?" matches any one character except "/"' do
        it "matches one character at the beginning if there's a ?" do
          gitignore '?our'

          expect(subject).not_to match_files('fouled', 'fear', 'favour', 'fa/our', 'foul')
          expect(subject).to match_files('tour', 'four')
        end

        it "doesn't match a slash" do
          gitignore 'fa?our'

          expect(subject).not_to match_files('fouled', 'fear', 'tour', 'four', 'fa/our', 'foul')
          expect(subject).to match_files('favour')
        end

        it 'matches per ?' do
          gitignore 'f??r'

          expect(subject).not_to match_files('fouled', 'tour', 'favour', 'fa/our', 'foul')
          expect(subject).to match_files('four', 'fear')
        end

        it "matches a single character at the end if there's a ?" do
          gitignore 'fou?'

          expect(subject).not_to match_files('fouled', 'fear', 'tour', 'favour', 'fa/our')
          expect(subject).to match_files('foul', 'four')
        end
      end

      describe '"[]" matches one character in a selected range' do
        it 'matches a single character in a character class' do
          gitignore 'a[ab]'

          expect(subject).not_to match_files('ac', 'ad', 'a[')
          expect(subject).to match_files('ab', 'aa')
        end

        it 'matches a single character in a character class range' do
          gitignore 'a[a-c]'

          expect(subject).not_to match_files('ad')
          expect(subject).to match_files('ab', 'aa', 'ab', 'ac')
        end

        it 'treats a backward character class range as only the first character of the range' do
          gitignore 'a[d-a]'

          expect(subject).to match_files('ad')
          expect(subject).not_to match_files('aa', 'ac', 'ab', 'a-')
        end

        it 'treats a negated backward character class range as only the first character of the range' do
          gitignore 'a[^d-a]'

          expect(subject).not_to match_files('ad')
          expect(subject).to match_files('aa', 'ac', 'ab', 'a-')
        end

        it 'treats a escaped backward character class range as only the first character of the range' do
          gitignore 'a[\\]-\\[]'

          expect(subject).to match_files('a]')
          expect(subject).not_to match_files('a[')
        end

        it 'treats a negated escaped backward character class range as only the first character of the range' do
          gitignore 'a[^\\]-\\[]'

          expect(subject).not_to match_files('a]')
          expect(subject).to match_files('a[')
        end

        it 'treats a escaped character class range as as a range' do
          gitignore 'a[\\[-\\]]'

          expect(subject).to match_files('a]', 'a[')
          expect(subject).not_to match_files('a-')
        end

        it 'treats a negated escaped character class range as a range' do
          gitignore 'a[^\\[-\\]]'

          expect(subject).not_to match_files('a]', 'a[')
          expect(subject).to match_files('a-')
        end

        it 'treats an unnecessarily escaped character class range as a range' do
          gitignore 'a[\\a-\\c]'

          expect(subject).to match_files('aa', 'ab', 'ac')
          expect(subject).not_to match_files('a-')
        end

        it 'treats a negated unnecessarily escaped character class range as a range' do
          gitignore 'a[^\\a-\\c]'

          expect(subject).not_to match_files('aa', 'ab', 'ac')
          expect(subject).to match_files('a-')
        end

        it 'treats a backward character class range with other options as only the first character of the range' do
          gitignore 'a[d-ba]'

          expect(subject).to match_files('aa', 'ad')
          expect(subject).not_to match_files('ac', 'ab', 'a-')
        end

        it 'treats a negated backward character class range with other options as the first character of the range' do
          gitignore 'a[^d-ba]'

          expect(subject).not_to match_files('aa', 'ad')
          expect(subject).to match_files('ac', 'ab', 'a-')
        end

        it 'treats a backward char class range with other initial options as the first char of the range' do
          gitignore 'a[ad-b]'

          expect(subject).to match_files('aa', 'ad')
          expect(subject).not_to match_files('ac', 'ab', 'a-')
        end

        it 'treats a negated backward char class range with other initial options as the first char of the range' do
          gitignore 'a[^ad-b]'

          expect(subject).not_to match_files('aa', 'ad')
          expect(subject).to match_files('ac', 'ab', 'a-')
        end

        it 'treats a equal character class range as only the first character of the range' do
          gitignore 'a[d-d]'

          expect(subject).to match_files('ad')
          expect(subject).not_to match_files('aa', 'ac', 'ab', 'a-')
        end

        it 'treats a negated equal character class range as only the first character of the range' do
          gitignore 'a[^d-d]'

          expect(subject).not_to match_files('ad')
          expect(subject).to match_files('aa', 'ac', 'ab', 'a-')
        end

        it 'interprets a / after a character class range as not there' do
          gitignore 'a[a-c/]'

          expect(subject).not_to match_files('ad')
          expect(subject).to match_files('ab', 'aa', 'ac')
        end

        it 'interprets a / before a character class range as not there' do
          gitignore 'a[/a-c]'

          expect(subject).not_to match_files('ad')
          expect(subject).to match_files('ab', 'aa', 'ac')
        end

        it 'interprets a / before the dash in a character class range as any character from / to c' do
          gitignore 'a[+/-c]'

          # case insensitive match means 'd' is matched by the 'D' between '/' and 'c'.
          # so ad doesn't show up in either list because it depends on git case sensitivity
          expect(subject).not_to match_files('a!', 'a$')
          expect(subject).to match_files('ab', 'aa', 'ac', 'a[', 'a^', 'a+')
        end

        it 'interprets a / after the dash in a character class range as any character from start to /' do
          gitignore 'a["-/c]'

          expect(subject).not_to match_files('ab', 'aa', 'a[', 'ad', 'a^')
          expect(subject).to match_files('a+', 'a-', 'a$', 'ac') # +, -, $ are between " and /
        end

        it 'interprets a slash then dash then character to be a character range' do
          gitignore 'a[/-c]'

          # case insensitive match means 'd' is matched by the 'D' between '/' and 'c'.
          # so ad doesn't show up in either list because it depends on git case sensitivity
          expect(subject).not_to match_files('a-', 'a+', 'a$', 'a!')
          expect(subject).to match_files('ac', 'ab', 'aa', 'a[', 'a^')
        end

        it 'interprets a character then dash then slash to be a character range' do
          gitignore 'a["-/]'

          expect(subject).not_to match_files('ab', 'ac', 'a[', 'ad', 'a^', 'aa', 'ab', 'ac')
          expect(subject).to match_files('a+', 'a-', 'a$')
        end

        context 'without raising warnings' do
          # these edge cases raise warnings
          # they're edge-casey enough if you hit them you deserve warnings.
          before { allow(Warning).to receive(:warn) }

          # case insensitive match means 'd' is matched by the 'D' between '-' and 'c'.
          # so ad doesn't show up in either list because it depends on git case sensitivity
          it 'interprets dash dash character as a character range beginning with -' do
            gitignore 'a[--c]'

            expect(subject).not_to match_files('a+', 'a$')
            expect(subject).to match_files('a-', 'ab', 'ac', 'a[', 'a^', 'aa', 'ab', 'ac')
          end

          it 'interprets character dash dash as a character range ending with -' do
            gitignore 'a["--]'

            expect(subject).not_to match_files('ab', 'ac', 'a[', 'ad', 'a^', 'aa', 'ab', 'ac')
            expect(subject).to match_files('a-', 'a+', 'a$')
          end

          it 'interprets dash dash dash as a character range of only with -' do
            gitignore 'a[---]'

            expect(subject).not_to match_files('a+', 'a$', 'ab', 'ac', 'a[', 'ad', 'a^', 'aa', 'ab', 'ac')
            expect(subject).to match_files('a-')
          end

          it 'interprets character dash dash dash as a character range of only with " to - with literal -' do
            gitignore 'a["---]'

            expect(subject).not_to match_files('ab', 'ac', 'a[', 'ad', 'a^', 'aa', 'ab', 'ac')
            expect(subject).to match_files('a+', 'a$', 'a-')
          end

          it 'interprets dash dash dash character as a character range of only - with literal c' do
            gitignore 'a[---c]'

            expect(subject).not_to match_files('ab', 'a[', 'ad', 'a^', 'aa', 'ab')
            expect(subject).to match_files('a-', 'ac')
          end

          it 'interprets character dash dash character as a character range ending with - and a literal c' do
            # this could just as easily be interpreted the other way around (" is the literal, --c is the range),
            # but ruby regex and git seem to treat this edge case the same
            gitignore 'a["--c]'

            expect(subject).not_to match_files('ab', 'a[', 'ad', 'a^', 'aa', 'ab')
            expect(subject).to match_files('a-', 'ac', 'a+', 'a$')
          end
        end

        it '^ is not' do
          gitignore 'a[^a-c]'

          expect(subject).to match_files('ad')
          expect(subject).not_to match_files('ab', 'aa', 'ac')
        end

        # this doesn't appear to be documented anywhere i just stumbled onto it
        it '! is also not' do
          gitignore 'a[!a-c]'

          expect(subject).to match_files('ad')
          expect(subject).not_to match_files('ab', 'aa', 'ac')
        end

        it '[^/] matches everything' do
          gitignore 'a[^/]'

          expect(subject).to match_files('aa', 'ab', 'ac', 'ad', 'a^')
        end

        it '[^^] matches everything except literal ^' do
          gitignore 'a[^^]'

          expect(subject).to match_files('aa', 'ab', 'ac', 'ad')
          expect(subject).not_to match_files('a^')
        end

        it '[^/a] matches everything except a' do
          gitignore 'a[^/a]'

          expect(subject).to match_files('ab', 'ac', 'ad', 'a^')
          expect(subject).not_to match_files('aa')
        end

        it '[/^a] matches literal ^ and a' do
          gitignore 'a[/^a]'

          expect(subject).not_to match_files('ab', 'ac', 'ad')
          expect(subject).to match_files('aa', 'a^')
        end

        it '[/^] matches literal ^' do
          gitignore 'a[/^]'

          expect(subject).to match_files('a^')
          expect(subject).not_to match_files('aa', 'ab', 'ac', 'ad')
        end

        it '[\\^] matches literal ^' do
          gitignore 'a[\^]'

          expect(subject).to match_files('a^')
          expect(subject).not_to match_files('aa', 'ab', 'ac', 'ad')
        end

        it 'later ^ is literal' do
          gitignore 'a[a-c^]'

          expect(subject).not_to match_files('ad')
          expect(subject).to match_files('ab', 'aa', 'ac', 'a^')
        end

        it "doesn't match a slash even if you specify it last" do
          gitignore 'b[i/]b'

          expect(subject).not_to match_files('b/b')
          expect(subject).to match_files('bib')
        end

        it "doesn't match a slash even if you specify it alone" do
          gitignore 'b[/]b'

          expect(subject).not_to match_files('b/b', 'bb')
        end

        it 'empty class matches nothing' do
          gitignore 'b[]b'

          expect(subject).not_to match_files('b/b', 'bb', 'aa', 'ab')
        end

        it 'multiple empty class matches nothing' do
          gitignore 'b[]b', 'a[]a'

          expect(subject).not_to match_files('b/b', 'bb', 'aa', 'ab')
        end

        it 'empty class matches nothing after a rule that is matchable' do
          gitignore 'a*', 'b[]b'

          expect(subject).not_to match_files('b/b', 'bb')
          expect(subject).to match_files('aa', 'ab')
        end

        it 'empty class matches nothing before a rule that is matchable' do
          gitignore 'b[]b', 'a*'

          expect(subject).not_to match_files('b/b', 'bb')
          expect(subject).to match_files('aa', 'ab')
        end

        it "doesn't match a slash even if you specify it middle" do
          gitignore 'b[i/a]b'

          expect(subject).not_to match_files('b/b')
          expect(subject).to match_files('bib', 'bab')
        end

        it "doesn't match a slash even if you specify it start" do
          gitignore 'b[/ai]b'

          expect(subject).not_to match_files('b/b')
          expect(subject).to match_files('bib', 'bab')
        end

        it 'assumes an unfinished [ matches nothing' do
          gitignore 'a['

          expect(subject).not_to match_files('aa', 'ab', 'ac', 'bib', 'b/b', 'bab', 'a[')
        end

        it 'assumes an unfinished [ followed by \ matches nothing' do
          gitignore 'a[\\'

          expect(subject).not_to match_files('aa', 'ab', 'ac', 'bib', 'b/b', 'bab', 'a[')
        end

        it 'assumes an escaped [ is literal' do
          gitignore 'a\['

          expect(subject).not_to match_files('aa', 'ab', 'ac', 'bib', 'b/b', 'bab')
          expect(subject).to match_files('a[')
        end

        it 'assumes an escaped [ is literal inside a group' do
          gitignore 'a[\[]'

          expect(subject).not_to match_files('aa', 'ab', 'ac', 'bib', 'b/b', 'bab')
          expect(subject).to match_files('a[')
        end

        it 'assumes an unfinished [ matches nothing when negated' do
          gitignore '!a['

          expect(subject).not_to match_files('aa', 'ab', 'ac', 'bib', 'b/b', 'bab', 'a[')
        end

        it 'assumes an unfinished [bc matches nothing' do
          gitignore 'a[bc'

          expect(subject).not_to match_files('aa', 'ab', 'ac', 'bib', 'b/b', 'bab', 'a[', 'a[bc')
        end
      end

      # See fnmatch(3) and the FNM_PATHNAME flag for a more detailed description
    end

    describe 'A leading slash matches the beginning of the pathname.' do
      # For example, "/*.c" matches "cat-file.c" but not "mozilla-sha1/sha1.c".
      it 'matches only at the beginning of everything' do
        gitignore '/*.c'

        expect(subject).not_to match_files('mozilla-sha1/sha1.c')
        expect(subject).to match_files('cat-file.c')
      end
    end

    describe 'Two consecutive asterisks ("**") in patterns matched against full pathname may have special meaning:' do
      describe 'A leading "**" followed by a slash means match in all directories.' do
        # 'For example, "**/foo" matches file or directory "foo" anywhere, the same as pattern "foo".
        # "**/foo/bar" matches file or directory "bar" anywhere that is directly under directory "foo".'
        it 'matches files or directories in all directories' do
          gitignore '**/foo'

          expect(subject).not_to match_files('bar/bar/bar')
          expect(subject).to match_files('foo', 'bar/foo', 'bar/bar/foo/in_dir')
        end

        it 'matches nothing with double slash' do
          gitignore '**//foo'

          expect(subject).not_to match_files('bar/bar/bar', 'foo', 'bar/foo', 'bar/bar/foo/in_dir')
        end

        it 'matches all directories when only **/ (interpreted as ** then the trailing / for dir only)' do
          gitignore '**/'

          expect(subject).to match_files('bar/bar/bar', 'bar/foo', 'bar/bar/foo/in_dir')
          expect(subject).not_to match_files('foo')
        end

        it 'matches files or directories in all directories when repeated' do
          gitignore '**/**/foo'

          expect(subject).not_to match_files('bar/bar/bar')
          expect(subject).to match_files('foo', 'bar/foo', 'bar/bar/foo/in_dir')
        end

        it 'matches files or directories in all directories with **/*' do
          gitignore '**/*'

          expect(subject).to match_files('bar/bar/bar', 'foo', 'bar/foo', 'bar/bar/foo/in_dir')
        end

        it 'matches files or directories in all directories when also followed by a star before text' do
          gitignore '**/*foo'

          expect(subject).not_to match_files('bar/bar/bar')
          expect(subject).to match_files('foo', 'bar/foo', 'boofoo', 'bar/boofoo', 'bar/bar/foo/in_dir')
        end

        it 'matches files or directories in all directories when also followed by a star within text' do
          gitignore '**/f*o'

          expect(subject).not_to match_files('bar/bar/bar')
          expect(subject).to match_files('foo', 'bar/foo', 'fo', 'o/fo', 'bar/bar/foo/in_dir')
        end

        it 'matches files or directories in all directories when also followed by a star after text' do
          gitignore '**/fo*'

          expect(subject).not_to match_files('bar/bar/bar', 'ofo')
          expect(subject).to match_files('foo', 'bar/foo', 'bar/bar/foo/in_dir')
        end

        it 'matches files or directories in all directories when three stars' do
          gitignore '***/foo'

          expect(subject).not_to match_files('bar/bar/bar', 'barfoo')
          expect(subject).to match_files('foo', 'bar/foo', 'bar/bar/foo/in_dir')
        end
      end

      describe 'A trailing "/**" matches everything inside relative to the location of the .gitignore file.' do
        # For example, "abc/**" matches all files inside directory "abc",
        it 'matches files or directories inside the mentioned directory' do
          gitignore 'abc/**'

          expect(subject).not_to match_files('bar/bar/foo', 'bar/abc/foo')
          expect(subject).to match_files('abc/bar', 'abc/foo/bar')
        end

        it 'matches all directories inside the mentioned directory' do
          gitignore 'abc/**/'

          expect(subject).not_to match_files('abc/bar', 'bar/bar/foo', 'bar/abc/foo')
          expect(subject).to match_files('abc/foo/bar')
        end

        it 'matches files or directories inside the mentioned directory when ***' do
          gitignore 'abc/***'

          expect(subject).not_to match_files('bar/bar/foo', 'bar/abc/foo')
          expect(subject).to match_files('abc/bar', 'abc/foo/bar')
        end
      end

      describe 'A slash followed by two consecutive asterisks then a slash matches zero or more directories.' do
        # For example, "a/**/b" matches "a/b", "a/x/b", "a/x/y/b" and so on.'
        it 'matches multiple intermediate dirs' do
          gitignore 'a/**/b'

          expect(subject).not_to match_files('z/y', 'z/a/b', 'z/a/x/b', 'ab')
          expect(subject).to match_files('a/b', 'a/x/b', 'a/x/y/b')
        end

        it 'matches multiple intermediate dirs with multiple consecutive-asterisk-slashes' do
          gitignore 'a/**/b/**/c/**/d'

          expect(subject).to match_files('a/b/c/d', 'a/x/b/x/c/x/d', 'a/x/y/b/x/y/c/x/y/d')
          expect(subject).not_to match_files('z/y', 'z/a/b/c/d', 'z/a/x/b', 'abcd')
        end

        it 'matches multiple intermediate dirs when ***' do
          gitignore 'a/***/b'

          expect(subject).not_to match_files('z/y', 'z/a/b', 'z/a/x/b', 'ab')
          expect(subject).to match_files('a/b', 'a/x/b', 'a/x/y/b')
        end
      end

      describe 'Other consecutive asterisks are considered regular asterisks' do
        describe 'and will match according to the previous rules' do
          context 'with two stars' do
            it 'matches any number of characters at the beginning' do
              gitignore '**our'

              expect(subject).not_to match_files('few', 'fewer')
              expect(subject).to match_files('f/our', 'four', 'favour')
            end

            it "doesn't match a slash" do
              gitignore 'f**our'

              expect(subject).not_to match_files('few', 'fewer', 'f/our')
              expect(subject).to match_files('four', 'favour')
            end

            it 'matches any number of non-slash characters in the middle' do
              gitignore 'f**r'

              expect(subject).not_to match_files('f/our', 'few')
              expect(subject).to match_files('four', 'fewer', 'favour')
            end

            it 'matches any number of characters at the end' do
              gitignore 'few**'

              expect(subject).not_to match_files('f/our', 'four', 'favour')
              expect(subject).to match_files('few', 'fewer')

              # TODO: doesn't work sometimes
              # expect(subject).to match_files('fewest/!')
            end

            # not sure if this is a bug but this is git behaviour
            it 'matches any number of directories including none, when following a character, and anchors' do
              gitignore 'f**/our'

              expect(subject).not_to match_files('few', 'fewer', 'favour', 'file/four')
              expect(subject).to match_files('four', 'f/our')

              # TODO: doesn't work sometimes
              # expect(subject).to match_files('file/f/our')
            end
          end
        end
      end
    end

    it 'handles this specific edge case i stumbled across' do
      gitignore "Ȋ/\nfoo/"

      expect(subject).not_to match_files('bar/foo', 'baz/foo', 'bar/baz')
      expect(subject).to match_files('foo/bar')
    end
  end

  describe '.gitignore' do
    it_behaves_like 'the gitignore documentation'
  end

  describe '.ignore(patterns_from_file:)' do
    subject do
      described_class.ignore(patterns_from_file: gitignore_path)
    end

    it_behaves_like 'the gitignore documentation'
  end

  describe "root: '..'" do
    subject do
      Dir.chdir File.join(root, '..') do
        described_class.gitignore(root: root)
      end
    end

    around do |example|
      Dir.mkdir 'sublevel'
      Dir.chdir 'sublevel' do
        example.run
      end
    end

    let(:root) { Dir.pwd }

    it_behaves_like 'the gitignore documentation'
  end

  describe 'ignore(patterns)' do
    subject do
      described_class.ignore(ignore_rules)
    end

    let(:gitignore_read) { File.exist?(gitignore_path) ? File.read(gitignore_path) : '' }

    describe 'with string argument' do
      let(:ignore_rules) { gitignore_read }

      it_behaves_like 'the gitignore documentation'
    end

    describe 'with array argument' do
      let(:ignore_rules) { gitignore_read.each_line.to_a }

      it_behaves_like 'the gitignore documentation'
    end
  end

  describe '.only(patterns_from_file:)' do
    subject do
      described_class.only(patterns_from_file: include_path)
    end

    around do |example|
      $doing_include = true
      example.run
      $doing_include = false
    end

    let(:include_path) { File.join(root, '.gitignore') }

    it_behaves_like 'the gitignore documentation'

    describe "root: '..'" do
      subject do
        Dir.chdir File.join(root, '..') do
          described_class.only(
            patterns_from_file: include_path,
            root: root
          )
        end
      end

      around do |example|
        Dir.mkdir 'sublevel'
        Dir.chdir 'sublevel' do
          example.run
        end
      end

      let(:root) { Dir.pwd }

      it_behaves_like 'the gitignore documentation'
    end
  end

  describe 'only(patterns)' do
    subject do
      described_class.only(include_rules)
    end

    around do |example|
      $doing_include = true
      example.run
      $doing_include = false
    end

    let(:include_path) { File.join(root, '.gitignore') }
    let(:include_read) { File.exist?(include_path) ? File.read(include_path) : '' }

    describe 'with string argument' do
      let(:include_rules) { include_read }

      it_behaves_like 'the gitignore documentation'
    end

    describe 'with array argument' do
      let(:include_rules) { include_read.each_line.to_a }

      it_behaves_like 'the gitignore documentation'
    end
  end

  describe 'git ls-files', :real_git do
    subject { real_git }

    it_behaves_like 'the gitignore documentation'
  end
end
