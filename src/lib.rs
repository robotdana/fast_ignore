#[macro_use]

extern crate helix;
extern crate ignore;

use ignore::WalkBuilder;

ruby! {
    class FastIgnoreNative {
        struct {
            walk_builder: WalkBuilder,
        }

        def initialize(helix) {
            FastIgnoreNative { helix, walk_builder: WalkBuilder::new("./").hidden(false) }
        }

        def add_file(&mut self, files: Vec<String>) {
            for s in files {
                self.walk_builder.add_ignore(s);
            }
        }
    }
}
