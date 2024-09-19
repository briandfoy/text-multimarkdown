use strict;
use warnings;
use Test::More tests => 3;

use_ok('Text::MultiMarkdown', 'markdown');

my $m = Text::MultiMarkdown->new(
    heading_ids => 0
);

# This case works.

my $html1 = $m->markdown(<<"EOF");
- # Heading 1

- ## Heading 2
EOF

is( $html1, <<"EOF" );
<ul>
<li><h1>Heading 1</h1></li>
<li><h2>Heading 2</h2></li>
</ul>
EOF

# This case fails.

my $html2 = $m->markdown(<<"EOF");
- # Heading 1
- ## Heading 2
EOF

{
    local $TODO = 'Fails as lack of space between list elements means we only run span level tags, and headings are block level';
    is( $html2, <<'EOF' );
<ul>
<li><h1>Heading 1</h1></li>
<li><h2>Heading 2</h2></li>
</ul>
EOF

};
