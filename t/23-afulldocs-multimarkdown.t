use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);

use lib qq($Bin/lib);
use TestUtils;

my $docsdir = "$Bin/MultiMarkdown.mdtest";
my @files = get_files($docsdir);

plan tests => scalar(@files) + 1;

use_ok('Text::MultiMarkdown');

my $m = Text::MultiMarkdown->new();

run_tests($m, $docsdir, @files);
