use strict;
use warnings;
use Test::More;

my $class = 'Text::MultiMarkdown';
my @methods = qw(markdown to_html);

subtest 'sanity' => sub {
	use_ok($class) or BAIL_OUT( "Could not compile $class: Stopping" );
	can_ok $class, @methods;
	};

my $markdown = <<'EOF';
Foo

Bar
EOF

my $expected_html = <<'EOF';
<p>Foo</p>

<p>Bar</p>
EOF

subtest 'instance' => sub {
	my $m = $class->new;
	isa_ok $m, $class;
	can_ok $m, @methods;

	foreach my $method ( @methods ) {
		my $html = $m->$method($markdown);
		is $html, $expected_html, "$method returns expected HTML";
		}
	};

done_testing();
