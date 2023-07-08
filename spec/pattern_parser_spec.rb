# frozen_string_literal: true

RSpec.describe PathList::PatternParser do
  subject(:matchers) do
    described_class.build(
      patterns_arg,
      patterns_from_file: patterns_from_file,
      format: format_arg,
      root: root,
      polarity: polarity
    )
  end

  let(:patterns) { [] }
  let(:patterns_arg) { patterns_from_file ? [] : Array(patterns) }
  let(:patterns_from_file) { nil }
  let(:format_arg) { nil }
  let(:root) { nil }
  let(:polarity) { :ignore }

  around do |e|
    if patterns_from_file
      within_temp_dir { e.run }
    else
      e.run
    end
  end

  before do
    stub_file patterns.join("\n"), patterns_from_file if patterns_from_file
  end

  describe 'with blank patterns' do
    context 'when ignore' do
      let(:polarity) { :ignore }

      it 'matches everything' do
        expect(matchers).to be_like PathList::Matcher::Allow
      end
    end

    context 'when allow' do
      let(:polarity) { :allow }

      it 'matches everything' do
        expect(matchers).to be_like PathList::Matcher::Allow
      end
    end
  end

  context 'with patterns: "a", root: "/"' do
    let(:patterns) { 'a' }
    let(:root) { '/' }

    context 'when ignore' do
      let(:polarity) { :ignore }

      it 'ignores a' do
        expect(matchers).to be_like PathList::Matcher::LastMatch::Two.new([
          PathList::Matcher::Allow,
          PathList::Matcher::PathRegexp.new(%r{/a\z}, :ignore)
        ])
      end
    end

    context 'when allow' do
      let(:polarity) { :allow }

      it 'allows a, and implicitly any parents and children of a' do
        expect(matchers).to be_like PathList::Matcher::LastMatch.new([
          PathList::Matcher::Ignore,
          PathList::Matcher::PathRegexp.new(%r{/a(?:\z|/)}, :allow),
          PathList::Matcher::AllowAnyDir
        ])
      end
    end
  end

  context 'with patterns: "a", root: "/b"' do
    let(:patterns) { 'a' }
    let(:root) { '/b' }

    context 'when ignore' do
      let(:polarity) { :ignore }

      it 'ignores a' do
        expect(matchers).to be_like PathList::Matcher::LastMatch::Two.new([
          PathList::Matcher::Allow,
          PathList::Matcher::PathRegexp.new(%r{\A/b/(?:.*/)?a\z}, :ignore)
        ])
      end
    end

    context 'when allow' do
      let(:polarity) { :allow }

      it 'allows a, and implicitly any children of a' do
        expect(matchers).to be_like PathList::Matcher::LastMatch.new([
          PathList::Matcher::Ignore,
          PathList::Matcher::PathRegexp.new(%r{\A/b/(?:.*/)?a(?:\z|/)}, :allow),
          PathList::Matcher::MatchIfDir.new(
            PathList::Matcher::Any::Two.new([
              PathList::Matcher::ExactString::Set.new(['/', '/b'], :allow),
              PathList::Matcher::PathRegexp.new(%r{\A/b/}, :allow)
            ])
          )
        ])
      end
    end
  end

  context 'with patterns: ["a[b]", "a[^c]"], root: "/"' do
    let(:patterns) { ['a[b]', 'a[^c]'] }
    let(:root) { '/' }

    context 'when ignore' do
      let(:polarity) { :ignore }

      it "doesn't merge the character classes" do
        expect(matchers).to be_like PathList::Matcher::LastMatch::Two.new([
          PathList::Matcher::Allow,
          PathList::Matcher::PathRegexp.new(%r{/a(?:(?!/)[b]\z|(?!/)[^c]\z)}, :ignore)
        ])
      end
    end

    context 'when allow' do
      let(:polarity) { :allow }

      it "doesn't merge the character classes" do
        expect(matchers).to be_like PathList::Matcher::LastMatch.new([
          PathList::Matcher::Ignore,
          PathList::Matcher::PathRegexp.new(%r{/a(?:(?!/)[b](?:\z|/)|(?!/)[^c](?:\z|/))}, :allow),
          PathList::Matcher::AllowAnyDir
        ])
      end
    end
  end

  context 'with patterns: ["*", "!./foo", "!/a/b/c/baz"], root: "/a/b/c", format: :glob_gitignore' do
    let(:patterns) { ['*', '!./foo', '!/a/b/c/baz'] }
    let(:root) { '/a/b/c' }
    let(:format_arg) { :glob_gitignore }

    context 'when ignore' do
      let(:polarity) { :ignore }

      it 'builds correct matchers (correctness verified by other tests, i just want visibility)' do
        expect(matchers).to be_like PathList::Matcher::LastMatch.new([
          PathList::Matcher::Allow,
          PathList::Matcher::PathRegexp.new(%r{\A/a/b/c/}, :ignore),
          PathList::Matcher::ExactString::Set.new([
            '/a/b/c/foo',
            '/a/b/c/baz'
          ], :allow)
        ])
      end
    end

    context 'when allow' do
      let(:polarity) { :allow }

      it 'builds correct matchers (correctness verified by other tests, i just want visibility)' do
        expect(matchers).to be_like PathList::Matcher::LastMatch.new([
          PathList::Matcher::Ignore,
          PathList::Matcher::PathRegexp.new(%r{\A/a/b/c/}, :allow),
          PathList::Matcher::MatchIfDir.new(
            PathList::Matcher::Any::Two.new([
              PathList::Matcher::ExactString::Set.new(['/', '/a', '/a/b', '/a/b/c'], :allow),
              PathList::Matcher::PathRegexp.new(%r{\A/a/b/c/}, :allow)
            ])
          ),
          PathList::Matcher::ExactString::Set.new([
            '/a/b/c/foo',
            '/a/b/c/baz'
          ], :ignore)
        ])
      end
    end
  end

  context 'with patterns: ["a*", "/b*", "d*", "/bb*", "!c/d*", "**/e*", "# comment"], root: "/f/g"' do
    let(:patterns) { ['a*', '/b*', 'd*', '/bb*', '!c/d*', '**/e*', '# comment'] }
    let(:root) { '/f/g/' }

    context 'when ignore' do
      let(:polarity) { :ignore }

      it 'builds correct matchers (correctness verified by other tests, i just want visibility)' do
        expect(matchers).to be_like PathList::Matcher::LastMatch.new([
          PathList::Matcher::Allow,
          PathList::Matcher::PathRegexp.new(
            %r{\A/f/g/(?:b[^\/]*\z|bb[^\/]*\z|(?:.*/)?(?:a[^\/]*\z|d[^\/]*\z))}, :ignore
          ),
          PathList::Matcher::PathRegexp.new(%r{\A/f/g/c/d[^\/]*\z}, :allow),
          PathList::Matcher::PathRegexp.new(%r{\A/f/g/(?:.*/)?e[^\/]*\z}, :ignore)
        ])
      end
    end

    context 'when allow' do
      let(:polarity) { :allow }

      it 'builds correct matchers (correctness verified by other tests, i just want visibility)' do
        expect(matchers).to be_like PathList::Matcher::LastMatch.new([
          PathList::Matcher::Ignore,
          PathList::Matcher::PathRegexp.new(
            %r{\A/f/g/(?:b[^\/]*(?:\z|/)|bb[^\/]*(?:\z|/)|(?:.*/)?(?:a[^\/]*(?:\z|/)|d[^\/]*(?:\z|/)|e[^\/]*/))},
            :allow
          ),
          PathList::Matcher::MatchIfDir.new(
            PathList::Matcher::Any::Two.new([
              PathList::Matcher::ExactString::Set.new(['/', '/f', '/f/g'], :allow),
              PathList::Matcher::PathRegexp.new(%r{\A/f/g/}, :allow)
            ])
          ),
          PathList::Matcher::PathRegexp.new(%r{\A/f/g/c/d[^\/]*\z}, :ignore),
          PathList::Matcher::PathRegexp.new(%r{\A/f/g/(?:.*/)?e[^\/]*\z}, :allow)
        ])
      end
    end
  end
end
