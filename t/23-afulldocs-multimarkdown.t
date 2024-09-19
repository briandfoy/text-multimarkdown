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
	tidy();

	my $docsdir = "$Bin/MultiMarkdown.mdtest";
	my @files = get_files($docsdir);

	my $m = Text::MultiMarkdown->new();

	run_tests($m, $docsdir, @files);
	};

done_testing();
