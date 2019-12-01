mod fnmatch;
extern crate regex;
use regex::Regex;

pub struct Rule {
  pub re: Regex,
  pub dir_only: bool,
  pub negation: bool
}

impl Rule {
  pub fn new(rule: &str, dir_only: bool, negation: bool) -> Rule {
    Rule {
      re: fnmatch::fnmatch_to_regex(rule),
      dir_only: dir_only,
      negation: negation,
    }
  }
  pub fn is_match(&self, path: &str) -> bool {
    self.re.is_match(path)
  }
}
