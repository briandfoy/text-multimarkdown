use strict;
use warnings;
use Test::More;

use_ok('Text::MultiMarkdown', 'markdown');

my $m = Text::MultiMarkdown->new();
my $html1 = $m->markdown(<<"EOF");
- a
- b

1. 1
2. 2
EOF

{
    local $TODO = 'Does not work as expected in current Markdown, known bug.';

    is( $html1, <<"EOF" );
<ul>
<li>a</li>
<li>b</li>
</ul>

<ol>
<li>1</li>
<li>2</li>
</ol>
EOF

};

done_testing();
