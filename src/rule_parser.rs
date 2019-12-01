struct RuleParser {
  rule: String,
  root: &str,
  allow: bool,
  expand_path: bool,
  dir_only: bool,
  negation: bool,
  anchored: bool,
  prefix: &str,
}

impl RuleParser {
  pub fn new(rule: &str, root: &str, allow: bool, expand_path: bool) -> RuleParser {
    RuleParser {
      rule: &rule.to_owner(),
      root,
      allow,
      expand_path,
      dir_only: false,
      negation: allow,
      anchored: false,
      prefix: "",
    }
  }

  pub fn parse(&mut self) -> (bool, Vec<Rule>) {
    self.strip();
    if skip() {
      return (false, vec![]);
    }
    self.extract_dir_only();
    if self.expand_path {
      self.process_expand_path();
    }
    self.extract_dir_only();
    self.extract_negation();
    self.prefix();

    (self.anchored, self.rules())
  }

  fn strip(&mut self) {
    self.rule = self.rule.trim_end_matches('\n');
    if !self.rule.ends_with("\\ ") {
      self.rule = rule.trim_end();
    }
  }

  fn process_expand_path(&mut self) {
    if self.rule.starts_with('~') ||
      self.rule.starts_with('/') ||
      self.rule.starts_with("./") ||
      self.rule.starts_with("../") {
        self.rule = Path.new(self.rule).canonicalize.unwrap().to_string_lossy();
      }
  }

  fn extract_negation(&mut self) {
    if self.rule.starts_with('!') {
      self.negation = !allow;
      self.rule = self.rule.trim_start_matches('!');
    }
  }

  fn extract_dir_only(&mut self) {
    if self.rule.ends_with('/') {
      self.rule = self.rule.trim_end_matches('/');
    }
  }

  fn prefix(&mut self) {
    if self.rule.starts_with('/') {
      self.anchored = true;
    } else if self.rule.ends_with("/**") || rule.contains("/**/") {
      self.anchored = true;
      self.prefix = "/";
    } else {
      self.prefix = "/**/";
    }
  }

  fn skip(&self) -> bool {
    self.rule.is_empty() || self.rule.starts_with('#')
  }
}

