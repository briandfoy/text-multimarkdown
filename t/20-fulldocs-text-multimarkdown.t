use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);

our $TIDY = 0;

use lib qq($Bin/lib);
use TestUtils;

my $docsdir = "$Bin/Text-MultiMarkdown.mdtest";
my @files = get_files($docsdir);

plan tests => scalar(@files) + 2;

use_ok('Text::MultiMarkdown');

my $m = Text::MultiMarkdown->new(
	use_metadata  => 1,
);
{
	my $has_warned = 0;
	local $SIG{__WARN__} = sub {
		$has_warned++;
		warn(@_);
	};
	run_tests($m, $docsdir, @files);
	is($has_warned, 0, 'No warnings expected');
};

done_testing();


1;
