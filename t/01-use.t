use strict;
use warnings;
use Test::More;

my $class = 'Text::MultiMarkdown';

use_ok($class)
	or BAIL_OUT( "Could not compile $class: Stopping" );

done_testing;
