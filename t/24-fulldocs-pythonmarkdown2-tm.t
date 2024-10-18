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

	my $m = Text::MultiMarkdown->new(
		use_metadata => 0,
		heading_ids  => 0, # Remove MultiMarkdown behavior change in <hX> tags.
		img_ids      => 0, # Remove MultiMarkdown behavior change in <img> tags.
		);

	my $docsdir = "$Bin/docs-pythonmarkdown2-tm-cases-pass";
	my @files = get_files($docsdir);

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
