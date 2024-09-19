use strict;
use warnings;
use Test::More;


my $class = 'Text::MultiMarkdown';
my @methods = qw(markdown to_html);

subtest 'sanity' => sub {
	use_ok($class) or BAIL_OUT( "Could not compile $class: Stopping" );
	can_ok $class, @methods;
	};

subtest 'foo' => sub {
	my $instr = q{A trivial block of text with a WikiWord};
	my $outstr = qq{<p>A trivial block of text with a <a href="WikiWord">WikiWord</a></p>\n};

	my $m = $class->new(
		use_wikilinks => 1,
		);
	isa_ok $m, $class;
	can_ok $m, @methods;

	foreach my $method ( @methods ) {
		is $m->$method($instr) => $outstr, 'Markdown with wiki links, no base url';
		}
	};

subtest 'base_url' => sub {
	my $instr = q{A trivial block of text with a WikiWord};
	my $outstr = qq{<p>A trivial block of text with a <a href="http://www.test.com/WikiWord">WikiWord</a></p>\n};

	my $m = $class->new(
		use_wikilinks => 1,
		base_url => 'http://www.test.com/',
		);
	isa_ok $m, $class;
	can_ok $m, @methods;

	foreach my $method ( @methods ) {
		is $m->$method($instr) => $outstr, 'Markdown with wiki links, with base url in instance';
		}
	};

subtest 'metadata' => sub {
	my $instr  = qq{base url: http://www.test.com/\n\nA trivial block of text with a WikiWord};
	my $outstr = qq{base url: http://www.test.com/<br />\n\n<p>A trivial block of text with a <a href="http://www.test.com/WikiWord">WikiWord</a></p>\n};

	my $m = $class->new(
		use_wikilinks => 1,
		use_metadata   => 1,
		);
	isa_ok $m, $class;
	can_ok $m, @methods;

	foreach my $method ( @methods ) {
		is $m->$method($instr) => $outstr, 'Markdown with wiki links, with base url in metadata';
		}
	};

done_testing();
