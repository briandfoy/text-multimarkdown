use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);

use lib qq($Bin/lib);
use TestUtils;

my $class = 'Text::MultiMarkdown';
my @methods = qw(markdown to_html);

subtest 'sanity' => sub {
	use_ok($class) or BAIL_OUT( "Could not compile $class: Stopping" );
	can_ok $class, @methods;
	};

subtest 'files' => sub {
	my $m = Text::MultiMarkdown->new;
	isa_ok $m, $class;

	my $docsdir = "$Bin/docs-multimarkdown-todo";
	my @files = get_files($docsdir);

	TODO: {
		local $TODO = 'These tests are known broken';
		subtest 'todo' => sub { local $SIG{__WARN__} = sub { 1 }; run_tests($m, $docsdir, @files) };
		}
	};

done_testing();
