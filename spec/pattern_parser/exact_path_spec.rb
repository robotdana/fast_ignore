# frozen_string_literal: true

RSpec.describe PathList::PatternParser::ExactPath do
  subject(:matcher) { described_class.new(path, polarity, nil).matcher }

  let(:path) { '/path/to/exact/something' }
  let(:candidate_path) { path }
  let(:candidate) { PathList::Candidate.new(candidate_path, true) }
  let(:polarity) { :allow }

  describe '#implicit_matcher' do
    subject(:matcher) { described_class.new(path, polarity, nil).implicit_matcher }

    it 'builds a regex that matches parent and child somethings' do
      expect(matcher).to be_like(
        PathList::Matcher::Any::Two.new([
          PathList::Matcher::MatchIfDir.new(
            PathList::Matcher::ExactString::Set.new(['/', '/path', '/path/to', '/path/to/exact'], :allow)
          ),
          PathList::Matcher::PathRegexp.new(%r{\A/path/to/exact/something/}, :allow)
        ])
      )
    end

    describe 'with root and relative path' do
      subject(:matcher) { described_class.new('./exact/something', polarity, '/path/to').implicit_matcher }

      it 'builds a regex that matches parent and child somethings' do
        expect(matcher).to be_like(
          PathList::Matcher::Any::Two.new([
            PathList::Matcher::MatchIfDir.new(
              PathList::Matcher::ExactString::Set.new(['/', '/path', '/path/to', '/path/to/exact'], :allow)
            ),
            PathList::Matcher::PathRegexp.new(%r{\A/path/to/exact/something/}, :allow)
          ])
        )
      end
    end

    it "doesn't need to match exact path" do
      expect(matcher.match(PathList::Candidate.new(path, true))).to be_nil
    end

    it 'matches most parent path' do
      expect(matcher.match(PathList::Candidate.new('/path', true)))
        .to be :allow
    end

    it 'matches most parent path regardless of case' do
      expect(matcher.match(PathList::Candidate.new('/PATH', true))).to be :allow
    end

    it 'matches parent path' do
      expect(matcher.match(PathList::Candidate.new('/path/to', true)))
        .to be :allow
    end

    it 'matches child path' do
      expect(matcher.match(PathList::Candidate.new("#{path}/child", true)))
        .to be :allow
    end

    it 'matches grandchild path' do
      expect(matcher.match(PathList::Candidate.new("#{path}/child/child", true)))
        .to be :allow
    end

    it "doesn't match path starting with the same string" do
      expect(matcher.match(PathList::Candidate.new("#{path}_part_2", true)))
        .to be_nil
    end

    it "doesn't match parent path starting with the same string" do
      expect(matcher.match(PathList::Candidate.new('/path/to/exact-ish/something', true)))
        .to be_nil
    end

    it "doesn't match path sibling" do
      expect(matcher.match(PathList::Candidate.new('/path/to/exact/other', true)))
        .to be_nil
    end

    it "doesn't match path concatenation" do
      expect(matcher.match(PathList::Candidate.new('/pathtoexactsomething', true))) # spellr:disable-line
        .to be_nil
    end
  end

  describe '#matcher' do
    subject(:matcher) { described_class.new(path, polarity, nil).matcher }

    let(:polarity) { :ignore }

    it 'builds a matcher that matches exact something' do
      expect(matcher).to be_like(
        PathList::Matcher::ExactString.new('/path/to/exact/something', :ignore)
      )
    end

    it 'matches exact path' do
      expect(matcher.match(PathList::Candidate.new(path, true))).to be :ignore
    end

    it 'matches exact path case insensitively' do
      expect(matcher.match(PathList::Candidate.new(path.upcase, true))).to be :ignore
    end

    it "doesn't match most parent path" do
      expect(matcher.match(PathList::Candidate.new('/path', true)))
        .to be_nil
    end

    it "doesn't match parent path" do
      expect(matcher.match(PathList::Candidate.new('/path/to', true)))
        .to be_nil
    end

    it "doesn't match child path" do
      expect(matcher.match(PathList::Candidate.new("#{path}/child", true)))
        .to be_nil
    end
  end
end
