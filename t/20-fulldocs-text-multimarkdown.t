use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);

use lib qq($Bin/lib);
use TestUtils;

my $class = 'Text::MultiMarkdown';
my @methods = qw(markdown to_html);

subtest 'sanity' => sub {
	use_ok($class, qw(markdown multimarkdown_to_html)) or BAIL_OUT( "Could not compile $class: Stopping" );
	can_ok $class, @methods;
	};

subtest 'files' => sub {
	my $docs_dir = "$Bin/Text-MultiMarkdown.mdtest";
	ok -e $docs_dir, "input source directory <$docs_dir> exists";
	my @files = get_files($docs_dir);

	my $m = $class->new( use_metadata  => 1 );
	isa_ok $m, $class;
	can_ok $m, @methods;

	my $has_warned = 0;
	local $SIG{__WARN__} = sub {
		$has_warned++;
		warn(@_);
		};
	run_tests($m, $docs_dir, @files);

	is $has_warned, 0, 'No warnings expected';
	};

done_testing();


1;
