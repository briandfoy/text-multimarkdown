use strict;
use warnings;
use Test::More;
use Test::Exception;

my $instr = q{A trivial block of text};
my $outstr = q{<p>A trivial block of text</p>};

subtest 'sanity' => sub {
	use_ok( 'Text::MultiMarkdown', 'markdown' );
};

subtest 'function form' => sub {
	lives_ok {
		$outstr = markdown($instr);
	} 'Functional markdown works without an exception';

	chomp($outstr);

	is(
		$outstr => '<p>' . $instr . '</p>',
		'exported markdown function works'
	);
};

subtest 'class method' => sub {
    $outstr = '';
    lives_ok {
        $outstr = Text::MultiMarkdown->markdown($instr);
    } 'Lives (class method)';

    chomp($outstr);

    is($outstr, "<p>$instr</p>", 'Text::MultiMarkdown->markdown() works (as class method)');
};

done_testing();
