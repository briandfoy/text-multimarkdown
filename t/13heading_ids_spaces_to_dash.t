use utf8;
use strict;
use warnings;
use Test::More;

my $input = <<"EOF";
# First Level Heading

this is some text

## Second level

### Third level
EOF


subtest sanity => sub {
	use_ok('Text::MultiMarkdown', 'markdown');
};

subtest "no spaces to dash" => sub {
	my $expected = <<"HERE";
<h1 id="firstlevelheading">First Level Heading</h1>

<p>this is some text</p>

<h2 id="secondlevel">Second level</h2>

<h3 id="thirdlevel">Third level</h3>
HERE

	my $m = Text::MultiMarkdown->new;
	my $got = eval { $m->markdown($input); };
	my $at = $@;

	diag( "eval failed with: $at" );
	ok(!$at, "No exception from markdown") or diag( "eval failed with: $at" );
	is( $got, $expected );
};

subtest "spaces to dash" => sub {
	my $expected = <<"EOF";
<h1 id="first-level-heading">First Level Heading</h1>

<p>this is some text</p>

<h2 id="second-level">Second level</h2>

<h3 id="third-level">Third level</h3>
EOF

	my $m = Text::MultiMarkdown->new(
		heading_ids_spaces_to_dash => 1
	);
	my $got = eval { $m->markdown($input) };

	ok(!$@, "No exception from markdown ($@)");

	is( $got, $expected );
};


done_testing();
