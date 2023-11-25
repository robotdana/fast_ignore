# frozen_string_literal: true

RSpec.describe PathList::PatternParser::Shebang do
  subject(:matcher) { described_class.new(shebang, polarity, root).matcher }

  let(:case_insensitive) { false }
  let(:shebang) { 'ruby' }
  let(:root) { '/path/to/exact/something' }
  let(:candidate_path) { "#{root}/foo" }
  let(:shebang_line) { "#!/usr/bin/env -S #{shebang}" }
  let(:candidate) { PathList::Candidate.new(candidate_path, nil, shebang_line) }
  let(:polarity) { :allow }

  before do
    allow(PathList::CanonicalPath).to receive(:case_insensitive?).and_return(case_insensitive)
  end

  describe '#implicit_matcher' do
    subject(:matcher) { described_class.new(shebang, polarity, root).implicit_matcher }

    it 'builds a regex that matches parent somethings' do
      expect(matcher).to be_like(
        PathList::Matcher::MatchIfDir.new(
          PathList::Matcher::Any::Two.new([
            PathList::Matcher::ExactString::Set.new(
              ['/', '/path', '/path/to', '/path/to/exact', '/path/to/exact/something'], :allow
            ),
            PathList::Matcher::PathRegexp.new(%r{\A/path/to/exact/something/}, :allow)
          ])
        )
      )
    end

    it 'builds a regex that matches parent somethings when case insensitive' do
      allow(PathList::CanonicalPath).to receive(:case_insensitive?).and_return(true)

      expect(matcher).to be_like(
        PathList::Matcher::MatchIfDir.new(
          PathList::Matcher::Any::Two.new([
            PathList::Matcher::ExactString::Set::CaseInsensitive.new(
              ['/', '/path', '/path/to', '/path/to/exact', '/path/to/exact/something'], :allow
            ),
            PathList::Matcher::PathRegexp::CaseInsensitive.new(%r{\A/path/to/exact/something/}, :allow)
          ])
        )
      )
    end

    it 'matches most parent path' do
      expect(matcher.match(PathList::Candidate.new('/path', true)))
        .to be :allow
    end

    it 'matches exact case' do
      expect(matcher.match(PathList::Candidate.new('/PATH', true))).to be_nil
    end

    context 'when case insensitive' do
      let(:case_insensitive) { true }

      it 'matches most parent path regardless of case' do
        expect(matcher.match(PathList::Candidate.new('/PATH', true))).to be :allow
      end
    end

    it 'matches parent path' do
      expect(matcher.match(PathList::Candidate.new('/path/to', true)))
        .to be :allow
    end
  end

  describe '#matcher' do
    subject(:matcher) { described_class.new(shebang, polarity, root).matcher }

    let(:polarity) { :ignore }

    it 'builds a matcher that matches exact something' do
      expect(matcher).to be_like(
        PathList::Matcher::MatchUnlessDir.new(
          PathList::Matcher::PathRegexpWrapper.new(
            %r{\A/path/to/exact/something/(?:.*/)?[^/\.]*\z},
            PathList::Matcher::ShebangRegexp.new(/\A\#!.*\bruby\b/, :ignore)
          )
        )
      )
    end

    it 'matches exact path' do
      expect(matcher.match(PathList::Candidate.new(candidate_path, nil, shebang_line))).to be :ignore
    end

    it "doesn't match if the path has a dot" do
      expect(matcher.match(PathList::Candidate.new("#{root}/my.path", nil, shebang_line))).to be_nil
    end

    it "doesn't match if the path starts with a dot" do
      expect(matcher.match(PathList::Candidate.new("#{root}/.mypath", nil, shebang_line))).to be_nil
    end

    it 'matches if a parent dir has a dot' do
      expect(matcher.match(PathList::Candidate.new("#{root}/.mydir/foo", nil, shebang_line))).to be :ignore
    end

    it "doesn't match the shebang line case insensitively" do
      expect(matcher.match(PathList::Candidate.new(candidate_path, nil, '#!/bin/RUBY'))).to be_nil
    end

    it "doesn't match the shebang line case with subwords" do
      expect(matcher.match(PathList::Candidate.new(candidate_path, nil, '#!/bin/jruby'))).to be_nil
    end

    it 'matches exact case' do
      expect(matcher.match(PathList::Candidate.new("#{root.upcase}/foo", nil, shebang_line))).to be_nil
    end

    context 'when case insensitive' do
      let(:case_insensitive) { true }

      it 'matches most parent path regardless of case' do
        expect(matcher.match(PathList::Candidate.new("#{root.upcase}/foo", nil, shebang_line))).to be :ignore
      end
    end
  end
end
