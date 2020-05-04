# frozen_string_literal: true

RSpec.describe FastIgnore do
  around { |e| within_temp_dir { e.run } }

  let(:root) { Dir.pwd }

  shared_examples 'auto nested gitignore files' do
    describe 'Patterns read from a .gitignore file in the same directory as the path, or in any parent directory' do
      # (up to the toplevel of the work tree) # we consider root the root

      describe 'with patterns in the higher level files being overridden by those in lower level files.' do
        before do
          create_file_list 'a/b/c', 'a/b/d', 'b/c', 'b/d'

          gitignore <<~GITIGNORE
            b/d
          GITIGNORE

          create_file 'a/.gitignore', <<~GITIGNORE
            b/c
          GITIGNORE
        end

        it 'ignores files in context by files' do
          expect(subject).to allow_files('a/b/d', 'b/c', 'a/.gitignore').and(disallow('a/b/c', 'b/d'))
        end
      end

      describe 'Patterns read from $GIT_DIR/info/exclude' do
        before do
          create_file_list 'a/b/c', 'a/b/d', 'b/c', 'b/d'

          gitignore <<~GITIGNORE
            b/d
          GITIGNORE

          create_file '.git/info/exclude', <<~GITIGNORE
            a/b/c
          GITIGNORE
        end

        it 'recognises .git/info/exclude files' do
          expect(subject).to allow_files('a/b/d', 'b/c').and(disallow('a/b/c', 'b/d'))
        end
      end
    end
  end
  shared_examples 'the gitignore documentation' do
    describe 'A blank line matches no files, so it can serve as a separator for readability.' do
      before { create_file_list 'foo', 'bar', 'baz' }

      it 'ignores nothing when gitignore is empty' do
        gitignore ''

        expect(subject).to allow_files('foo', 'bar', 'baz')
      end

      it 'ignores nothing when gitignore only contains newlines' do
        gitignore <<~GITIGNORE


        GITIGNORE

        expect(subject).to allow_files('foo', 'bar', 'baz')
      end

      it 'ignores mentioned files when gitignore includes newlines' do
        gitignore <<~GITIGNORE

          foo
          bar

        GITIGNORE

        expect(subject).to allow_files('baz').and(disallow('foo', 'bar'))
      end
    end

    describe 'A line starting with # serves as a comment.' do
      before { create_file_list '#foo', 'foo' }

      it "doesn't ignore files whose names look like a comment" do
        gitignore <<~GITIGNORE
          #foo
          foo
        GITIGNORE

        expect(subject).to allow_files('#foo').and(disallow('foo'))
      end

      describe 'Put a backslash ("\") in front of the first hash for patterns that begin with a hash' do
        it 'ignores files whose names look like a comment when prefixed with a backslash' do
          gitignore <<~GITIGNORE
            \\#foo
          GITIGNORE

          expect(subject).to allow_files('foo').and(disallow('#foo'))
        end
      end
    end

    describe 'Trailing spaces are ignored unless they are quoted with backslash ("\")' do
      before { create_file_list 'foo', 'foo ', 'foo  ' }

      it 'ignores trailing spaces in the gitignore file' do
        gitignore 'foo  '

        expect(subject).to allow_files('foo  ', 'foo ').and(disallow('foo'))
      end

      it "doesn't ignore trailing spaces if there's a backslash" do
        gitignore "foo \\ \n"

        expect(subject).to allow_files('foo', 'foo ').and(disallow('foo  '))
      end

      it "doesn't ignore trailing spaces if there's a backslash before every space" do
        gitignore "foo\\ \\ \n"

        expect(subject).to allow_files('foo', 'foo ').and(disallow('foo  '))
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
          gitignore <<~GITIGNORE
            foo/
          GITIGNORE

          expect(subject).to allow_files('bar/foo', 'baz/foo', 'bar/baz').and(disallow('foo/bar'))
        end
      end
    end

    # The slash / is used as the directory separator.
    # Separators may occur at the beginning, middle or end of the .gitignore search pattern.
    describe 'If there is a separator at the beginning or middle (or both) of the pattern' do
      before { create_file_list 'doc/frotz/b', 'a/doc/frotz/c', 'd/doc/frotz' }

      describe 'then the pattern is relative to the directory level of the particular .gitignore file itself.' do
        # For example, a pattern doc/frotz/ matches doc/frotz directory, but not a/doc/frotz directory;
        # The pattern doc/frotz and /doc/frotz have the same effect in any .gitignore file.
        # In other words, a leading slash is not relevant if there is already a middle slash in the pattern.
        it 'includes files relative to the git dir with a middle slash' do
          gitignore 'doc/frotz'

          expect(subject).to disallow('doc/frotz/b').and(allow_files('a/doc/frotz/c'))
        end
      end

      describe 'Otherwise the pattern may also match at any level below the .gitignore level.' do
        # frotz/ matches frotz and a/frotz that is a directory

        it 'includes files relative to the git dir with a middle slash' do
          gitignore 'frotz/'

          expect(subject).to disallow('doc/frotz/b', 'a/doc/frotz/c').and(allow_files('d/doc/frotz'))
        end
      end
    end

    describe 'An optional prefix "!" which negates the pattern' do
      describe 'any matching file excluded by a previous pattern will become included again.' do
        before { create_file_list 'foo', 'foe' }

        it 'includes previously excluded files' do
          gitignore <<~GITIGNORE
            fo*
            !foo
          GITIGNORE

          expect(subject).to allow_files('foo').and(disallow('foe'))
        end

        it 'is read in order' do
          gitignore <<~GITIGNORE
            !foo
            fo*
          GITIGNORE

          expect(subject).to disallow('foe', 'foo')
        end

        it 'has no effect if not negating anything' do
          gitignore <<~GITIGNORE
            !foo
          GITIGNORE
          expect(subject).to allow_files('foe', 'foo')
        end
      end

      describe 'It is not possible to re-include a file if a parent directory of that file is excluded' do
        # Git doesn't list excluded directories for performance reasons
        # so any patterns on contained files have no effect no matter where they are defined
        before { create_file_list 'foo/bar', 'foo/foo', 'bar/bar' }

        it "doesn't include files inside previously excluded directories" do
          gitignore <<~GITIGNORE
            foo
            !foo/bar
          GITIGNORE

          expect(subject).to allow_files('bar/bar').and(disallow('foo/bar', 'foo/foo'))
        end
      end

      describe 'Put a backslash ("\") in front of the first "!" for patterns that begin with a literal "!"' do
        # for example, "\!important!.txt".'

        before { create_file_list '!important!.txt', 'important!.txt' }

        it 'matches files starting with a literal ! if its preceded by a backslash' do
          gitignore <<~GITIGNORE
            \\!important!.txt
          GITIGNORE

          expect(subject).to allow_files('important!.txt').and(disallow('!important!.txt'))
        end
      end
    end

    describe 'Otherwise, Git treats the pattern as a shell glob' do
      describe '"*" matches anything except "/"' do
        before { create_file_list 'f/our', 'few', 'four', 'fewer', 'favour' }

        it "matches any number of characters at the beginning if there's a star" do
          gitignore <<~GITIGNORE
            *our
          GITIGNORE

          expect(subject).to allow_files('few', 'fewer').and(disallow('f/our', 'four', 'favour'))
        end

        it "doesn't match a slash" do
          gitignore <<~GITIGNORE
            f*our
          GITIGNORE

          expect(subject).to allow_files('few', 'fewer', 'f/our').and(disallow('four', 'favour'))
        end

        it "matches any number of characters in the middle if there's a star" do
          gitignore <<~GITIGNORE
            f*r
          GITIGNORE

          expect(subject).to allow_files('f/our', 'few').and(disallow('four', 'fewer', 'favour'))
        end

        it "matches any number of characters at the end if there's a star" do
          gitignore <<~GITIGNORE
            few*
          GITIGNORE

          expect(subject).to allow_files('f/our', 'four', 'favour').and(disallow('few', 'fewer'))
        end
      end

      describe '"?" matches any one character except "/"' do
        before { create_file_list 'four', 'fouled', 'fear', 'tour', 'flour', 'favour', 'fa/our', 'foul' }

        it "matches any number of characters at the beginning if there's a star" do
          gitignore <<~GITIGNORE
            ?our
          GITIGNORE

          expect(subject).to allow_files('fouled', 'fear', 'favour', 'fa/our', 'foul').and(disallow('tour', 'four'))
        end

        it "doesn't match a slash" do
          gitignore <<~GITIGNORE
            fa?our
          GITIGNORE

          expect(subject).to allow_files('fouled', 'fear', 'tour', 'four', 'fa/our', 'foul').and(disallow('favour'))
        end

        it "matches any number of characters in the middle if there's a star" do
          gitignore <<~GITIGNORE
            f??r
          GITIGNORE

          expect(subject).to allow_files('fouled', 'tour', 'favour', 'fa/our', 'foul').and(disallow('four', 'fear'))
        end

        it "matches a single number of characters at the end if there's a ?" do
          gitignore <<~GITIGNORE
            fou?
          GITIGNORE

          expect(subject).to allow_files('fouled', 'fear', 'tour', 'favour', 'fa/our').and(disallow('foul', 'four'))
        end
      end

      describe '"[]" matches one character in a selected range' do
        before { create_file_list 'aa', 'ab', 'ac', 'ad', 'bib', 'b/b', 'bab', 'a[', 'bb', 'a^', 'a[bc' }

        it 'matches a single character in a character class' do
          gitignore <<~GITIGNORE
            a[ab]
          GITIGNORE

          expect(subject).to allow_files('ac').and(disallow('ab', 'aa'))
        end

        it 'matches a single character in a character class range' do
          gitignore <<~GITIGNORE
            a[a-c]
          GITIGNORE

          expect(subject).to allow_files('ad').and(disallow('ab', 'aa', 'ac'))
        end

        it '^ is not' do
          gitignore <<~GITIGNORE
            a[^a-c]
          GITIGNORE

          expect(subject).to disallow('ad').and(allow_files('ab', 'aa', 'ac'))
        end

        it '[^/] matches everything' do
          gitignore <<~GITIGNORE
            a[^/]
          GITIGNORE

          expect(subject).to disallow('aa', 'ab', 'ac', 'ad', 'a^')
        end

        it '[^^] matches everything except literal ^' do
          gitignore <<~GITIGNORE
            a[^^]
          GITIGNORE

          expect(subject).to disallow('aa', 'ab', 'ac', 'ad').and(allow_files('a^'))
        end

        it '[^/a] matches everything except a' do
          gitignore <<~GITIGNORE
            a[^/a]
          GITIGNORE

          expect(subject).to disallow('ab', 'ac', 'ad', 'a^').and(allow_files('aa'))
        end

        it '[/^a] matches literal ^ and a' do
          gitignore <<~GITIGNORE
            a[/^a]
          GITIGNORE

          expect(subject).to allow_files('ab', 'ac', 'ad').and(disallow('aa', 'a^'))
        end

        it '[/^] matches literal ^' do
          gitignore <<~GITIGNORE
            a[/^]
          GITIGNORE

          expect(subject).to disallow('a^').and(allow_files('aa', 'ab', 'ac', 'ad'))
        end

        it 'later ^ is literal' do
          gitignore <<~GITIGNORE
            a[a-c^]
          GITIGNORE

          expect(subject).to allow_files('ad').and(disallow('ab', 'aa', 'ac', 'a^'))
        end

        it "doesn't match a slash even if you specify it last" do
          gitignore <<~GITIGNORE
            b[i/]b
          GITIGNORE

          expect(subject).to allow_files('b/b').and(disallow('bib'))
        end

        it "doesn't match a slash even if you specify it alone" do
          gitignore <<~GITIGNORE
            b[/]b
          GITIGNORE

          expect(subject).to allow_files('b/b', 'bb')
        end

        it 'empty class matches nothing' do
          gitignore <<~GITIGNORE
            b[]b
          GITIGNORE

          expect(subject).to allow_files('b/b', 'bb')
        end

        it "doesn't match a slash even if you specify it middle" do
          gitignore <<~GITIGNORE
            b[i/a]b
          GITIGNORE

          expect(subject).to allow_files('b/b').and(disallow('bib', 'bab'))
        end

        it "doesn't match a slash even if you specify it start" do
          gitignore <<~GITIGNORE
            b[/ai]b
          GITIGNORE

          expect(subject).to allow_files('b/b').and(disallow('bib', 'bab'))
        end

        it 'assumes an unfinished [ matches nothing' do
          gitignore <<~GITIGNORE
            a[
          GITIGNORE

          expect(subject).to allow_files('aa', 'ab', 'ac', 'bib', 'b/b', 'bab', 'a[')
        end

        it 'assumes an unfinished [bc matches nothing' do
          gitignore <<~GITIGNORE
            a[bc
          GITIGNORE

          expect(subject).to allow_files('aa', 'ab', 'ac', 'bib', 'b/b', 'bab', 'a[', 'a[bc')
        end
      end

      # See fnmatch(3) and the FNM_PATHNAME flag for a more detailed description
    end

    describe 'A leading slash matches the beginning of the pathname.' do
      # For example, "/*.c" matches "cat-file.c" but not "mozilla-sha1/sha1.c".
      before { create_file_list 'cat-file.c', 'mozilla-sha1/sha1.c' }

      it 'matches only at the beginning of everything' do
        gitignore <<~GITIGNORE
          /*.c
        GITIGNORE

        expect(subject).to allow_files('mozilla-sha1/sha1.c').and(disallow('cat-file.c'))
      end
    end

    describe 'Two consecutive asterisks ("**") in patterns matched against full pathname may have special meaning:' do
      describe 'A leading "**" followed by a slash means match in all directories.' do
        # 'For example, "**/foo" matches file or directory "foo" anywhere, the same as pattern "foo".
        # "**/foo/bar" matches file or directory "bar" anywhere that is directly under directory "foo".'
        before { create_file_list 'foo', 'bar/foo', 'bar/bar/bar', 'bar/bar/foo/in_dir' }

        it 'matches files or directories in all directories' do
          gitignore <<~GITIGNORE
            **/foo
          GITIGNORE

          expect(subject).to allow_files('bar/bar/bar').and(disallow('foo', 'bar/foo', 'bar/bar/foo/in_dir'))
        end

        it 'matches files or directories in all directories when three stars' do
          gitignore <<~GITIGNORE
            ***/foo
          GITIGNORE

          expect(subject).to allow_files('bar/bar/bar').and(disallow('foo', 'bar/foo', 'bar/bar/foo/in_dir'))
        end
      end

      describe 'A trailing "/**" matches everything inside relative to the location of the .gitignore file.' do
        # For example, "abc/**" matches all files inside directory "abc",
        before { create_file_list 'abc/bar', 'abc/foo/bar', 'bar/abc/foo', 'bar/bar/foo' }

        it 'matches files or directories inside the mentioned directory' do
          gitignore <<~GITIGNORE
            abc/**
          GITIGNORE

          expect(subject).to allow_files('bar/bar/foo', 'bar/abc/foo').and(disallow('abc/bar', 'abc/foo/bar'))
        end

        it 'matches files or directories inside the mentioned directory when ***' do
          gitignore <<~GITIGNORE
            abc/***
          GITIGNORE

          expect(subject).to allow_files('bar/bar/foo', 'bar/abc/foo').and(disallow('abc/bar', 'abc/foo/bar'))
        end

        context 'when the gitignore root is down a level from the pwd' do
          let(:ignore_rules) { '' } # just some shared behaviour shenanigans
          let(:args) { { gitignore: false, ignore_files: File.join(root, 'bar', '.gitignore') } }

          it 'matches files relative to the gitignore' do
            create_file 'bar/.gitignore', <<~GITIGNORE
              abc/**
            GITIGNORE

            expect(subject).to allow_files('bar/bar/foo', 'abc/bar', 'abc/foo/bar').and(disallow('bar/abc/foo'))
          end
        end
      end

      describe 'A slash followed by two consecutive asterisks then a slash matches zero or more directories.' do
        # For example, "a/**/b" matches "a/b", "a/x/b", "a/x/y/b" and so on.'
        before { create_file_list 'a/b', 'a/x/b', 'a/x/y/b', 'z/a/b', 'z/a/x/b', 'z/y' }

        it 'matches multiple intermediate dirs' do
          gitignore <<~GITIGNORE
            a/**/b
          GITIGNORE

          expect(subject).to allow_files('z/y', 'z/a/b', 'z/a/x/b').and(disallow('a/b', 'a/x/b', 'a/x/y/b'))
        end

        it 'matches multiple intermediate dirs when ***' do
          gitignore <<~GITIGNORE
            a/***/b
          GITIGNORE

          expect(subject).to allow_files('z/y', 'z/a/b', 'z/a/x/b').and(disallow('a/b', 'a/x/b', 'a/x/y/b'))
        end
      end

      describe 'Other consecutive asterisks are considered regular asterisks' do
        describe 'and will match according to the previous rules' do
          context 'with two stars' do
            before { create_file_list 'f/our', 'few', 'four', 'fewer', 'favour' }

            it 'matches any number of characters at the beginning' do
              gitignore <<~GITIGNORE
                **our
              GITIGNORE

              expect(subject).to allow_files('few', 'fewer').and(disallow('f/our', 'four', 'favour'))
            end

            it "doesn't match a slash" do
              gitignore <<~GITIGNORE
                f**our
              GITIGNORE

              expect(subject).to allow_files('few', 'fewer', 'f/our').and(disallow('four', 'favour'))
            end

            it 'matches any number of characters in the middle' do
              gitignore <<~GITIGNORE
                f**r
              GITIGNORE

              expect(subject).to allow_files('f/our', 'few').and(disallow('four', 'fewer', 'favour'))
            end

            it 'matches any number of characters at the end' do
              gitignore <<~GITIGNORE
                few**
              GITIGNORE

              expect(subject).to allow_files('f/our', 'four', 'favour').and(disallow('few', 'fewer'))
            end
          end
        end
      end
    end
  end

  shared_examples 'common behaviour' do
    it 'ignore .git by default' do
      create_file_list '.gitignore', '.git/WHATEVER', 'WHATEVER'

      expect(subject).to disallow('.git/WHATEVER').and(allow_files('WHATEVER'))
    end
  end

  describe 'FastIgnore' do
    subject { described_class.new(relative: true, **args) }

    let(:args) { {} }
    let(:gitignore_path) { File.join(root, '.gitignore') }

    it_behaves_like 'the gitignore documentation'
    it_behaves_like 'common behaviour'
    it_behaves_like 'auto nested gitignore files'

    describe 'ignore_files:' do
      subject do
        described_class.new(
          relative: true,
          gitignore: false,
          ignore_files: ignore_files,
          **args
        )
      end

      describe 'with string argument' do
        let(:ignore_files) { gitignore_path }

        it_behaves_like 'the gitignore documentation'
        it_behaves_like 'common behaviour'
      end

      describe 'with array argument' do
        let(:ignore_files) { [gitignore_path, gitignore_path] }

        it_behaves_like 'the gitignore documentation'
        it_behaves_like 'common behaviour'
      end
    end

    describe 'with a root set' do
      subject do
        Dir.chdir File.join(root, '..') do
          described_class.new(relative: true, root: root, **args)
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
      it_behaves_like 'common behaviour'
    end

    describe 'ignore_rules:' do
      subject do
        described_class.new(
          relative: true,
          gitignore: false,
          ignore_rules: ignore_rules,
          **args
        )
      end

      let(:gitignore_read) { File.exist?(gitignore_path) ? File.read(gitignore_path) : '' }

      describe 'with string argument' do
        let(:ignore_rules) { gitignore_read }

        it_behaves_like 'the gitignore documentation'
        it_behaves_like 'common behaviour'
      end

      describe 'with array argument' do
        let(:ignore_rules) { gitignore_read.each_line.to_a }

        it_behaves_like 'the gitignore documentation'
        it_behaves_like 'common behaviour'
      end
    end
  end

  describe 'git ls-files' do
    subject do
      `git init && git add -N .`
      `git ls-files`.split("\n")
    end

    it_behaves_like 'the gitignore documentation'
    it_behaves_like 'common behaviour'
    it_behaves_like 'auto nested gitignore files'
  end
end
