package Text::MultiMarkdown;

use open qw(:std :utf8);
use utf8;
use strict;
use warnings;
use Test::More;

my $has_unidecode = eval { require Text::Unidecode };

my $class = 'Text::MultiMarkdown';

subtest 'sanity' => sub {
	use_ok $class or BAIL_OUT("$class did not compile. Stopping");
	can_ok $class, qw(_id_handler _default_id_handler _transliteration_id_handler _unicode_id_handler);
	};

subtest 'low level' => sub {
	my @dash_table = ( # label ascii-version translit-version unicode-version
		[ 'plain label',   ('plain-label') x 3],
		[ 'extra  spaces', ('extra-spaces') x 3],
		[ '  leading  spaces', ('leading-spaces') x 3],
		[ '123 leading digits', ('leading-digits') x 3],
		[ '--- leading dashes', ('leading-dashes') x 3],
		[ 'trailing dashes---', ('trailing-dashes') x 3],
		[ 'naîve citroën driver from føroyar',
			'nave-citron-driver-from-froyar',
			'naive-citroen-driver-from-foroyar',
			'naîve-citroën-driver-from-føroyar',
			],
		[ 'îëøabc', 'abc', 'ieoabc', 'îëøabc' ],
		);

	my @no_dash_table = ( # label ascii-version translit-version unicode-version
		[ 'plain label',   ('plainlabel') x 3],
		[ 'extra  spaces', ('extraspaces') x 3],
		[ '  leading  spaces', ('leadingspaces') x 3],
		[ '123 leading digits', ('leadingdigits') x 3],
		[ '--- leading dashes', ('leadingdashes') x 3],
		[ 'naîve citroën driver from føroyar',
			'navecitrondriverfromfroyar',
			'naivecitroendriverfromforoyar',
			'naîvecitroëndriverfromføroyar',
			],
		);

	my @table = (
		[ 'heading_ids_spaces_to_dash',    sub { local $_ = $_[0]; s/\s+/-/g; $_ }, \@dash_table    ],
		[ 'no heading_ids_spaces_to_dash', sub { $_[0] },                           \@no_dash_table ],
		);

	foreach my $big_row ( @table ) {
		my( $label, $pre_process, $table ) = @$big_row;

		subtest "<$label>" => sub {
			foreach my $row ( @$table ) {
				$row->[0] = $pre_process->($row->[0]);
				check_label_low_level($row);
				}
			};
		}
	};

=pod

subtest 'through instance' => sub {
	subtest 'no heading_ids_spaces_to_dash' => sub {
		my $mm = $class->new(

			);



	};

	subtest 'heading_ids_spaces_to_dash' => sub {


	};

	foreach my $row ( @table ) {
		my( $input, $ascii, $translit, $unicode ) = @$row;

		subtest $input => sub {
			is _default_id_handler( $input ),         $ascii,    'ASCII label';
			is _unicode_id_handler( $input ),         $unicode,  'unicode label';
			SKIP: {
				skip "need Text::Iconv to test transliteraiont", 1 unless $has_unidecode;
				is _transliteration_id_handler( $input ), $translit, 'transliteration label';
				}
			};
		}
	};

=cut

sub check_label_low_level {
	my( $row ) = @_;
	my( $input, $ascii, $translit, $unicode ) = @$row;

	subtest $input => sub {
		is _default_id_handler( $input ),         $ascii,    'ASCII label';
		is _unicode_id_handler( $input ),         $unicode,  'unicode label';
		SKIP: {
			skip "need Text::Unidecode to test transliteration", 1 unless $has_unidecode;
			is _transliteration_id_handler( $input ), $translit, 'transliteration label';
			}
		};
}

done_testing;
