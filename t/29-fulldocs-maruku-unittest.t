use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);

use lib qq($Bin/lib);
use TestUtils;

my $docsdir = "$Bin/docs-maruku-unittest";
my @files = get_files($docsdir);

tidy();

subtest sanity => sub {
	use_ok('Text::MultiMarkdown');
	};


subtest files => sub {
	local $TODO = 'Ruby (maruku) tests, do not pass, but mostly due to spacing - pick them all up and go through them.';

	my $m = Text::MultiMarkdown->new(
		use_metadata => 0,
		heading_ids  => 0, # Remove MultiMarkdown behavior change in <hX> tags.
		img_ids      => 0, # Remove MultiMarkdown behavior change in <img> tags.
		);

	foreach my $file ( @files ) {
		subtest $file => sub {
			TODO: {
				local $TODO = 'Not many of the python markdown tests pass, but they ran off and did their own thing';
				run_tests( $m, $docsdir, $file );
				}
			};
		}
	};

done_testing();
