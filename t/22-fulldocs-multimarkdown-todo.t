use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);

require "$Bin/20-fulldocs-text-multimarkdown.t";

my $docsdir = "$Bin/docs-multimarkdown-todo";
my @files = get_files($docsdir);

plan tests => scalar(@files) + 1;

use_ok('Text::MultiMarkdown');

my $m = Text::MultiMarkdown->new();

{
    local $TODO = 'These tests are known broken';
    run_tests($m, $docsdir, @files);
};
