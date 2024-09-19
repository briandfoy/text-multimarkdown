use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);

require "$Bin/20-fulldocs-text-multimarkdown.t";

my $docsdir = "$Bin/docs-maruku-unittest";
my @files = get_files($docsdir);

tidy();

use_ok('Text::MultiMarkdown');

my $m = Text::MultiMarkdown->new(
    use_metadata => 0,
    heading_ids  => 0, # Remove MultiMarkdown behavior change in <hX> tags.
    img_ids      => 0, # Remove MultiMarkdown behavior change in <img> tags.
);

{
    local $TODO = 'Ruby (maruku) tests, do not pass, but mostly due to spacing - pick them all up and go through them..';
    run_tests($m, $docsdir, @files);

done_testing();
};
