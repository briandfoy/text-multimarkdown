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

subtest 'from markdown' => sub {
	my $method = 'markdown';
	my %Snippets = get_snippets();

	subtest 'headers-ascii' => sub {
		my $mm = $class->new();
		isa_ok $mm, $class;
		can_ok $mm, $method;

		ok exists  $Snippets{'headers-ascii'}, 'headers snippet exists';
		my $html = $mm->markdown( $Snippets{'headers-ascii'} );
		like $html, qr/<h1 id="firstlevelheading">/,   'h1 has right id';
		like $html, qr/<h2 id="secondlevelheading">/,  'h2 has right id';
		};

	subtest 'headers-unicode legacy' => sub {
		my $mm = $class->new();
		isa_ok $mm, $class;
		can_ok $mm, $method;

		ok exists  $Snippets{'headers-unicode'}, 'headers snippet exists';
		my $html = Text::MultiMarkdown::markdown( $Snippets{'headers-unicode'} );
		like $html, qr/<h1 id="firtlvlheaing">/, 'h1 has right id';
		like $html, qr/<h2 id="scdevelhedng">/,  'h2 has right id';
		};

	subtest 'headers-unicode legacy with dashes' => sub {
		my %options = ( heading_ids_spaces_to_dash => 1 );
		my $mm = $class->new( %options );
		isa_ok $mm, $class;
		can_ok $mm, $method;

		ok exists  $Snippets{'headers-unicode'}, 'headers snippet exists';
		my $html = $mm->markdown( $Snippets{'headers-unicode'},
			  );
		like $html, qr/<h1 id="firt-lvl-heaing">/, 'h1 has right id';
		like $html, qr/<h2 id="scd-evel-hedng">/,  'h2 has right id';
		};

	subtest 'headers-unicode transliteration with dashes' => sub {
		my %options = (
			heading_ids_spaces_to_dash => 1,
			transliterate_ids          => 1,
		);
		my $mm = $class->new( %options );
		isa_ok $mm, $class;
		can_ok $mm, $method;

		ok exists  $Snippets{'headers-unicode'}, 'headers snippet exists';
		my $html = $mm->markdown( $Snippets{'headers-unicode'},
			{ heading_ids_spaces_to_dash => 1, transliterate_ids => 1 }  );
		like $html, qr/<h1 id="first-leval-heading">/,  'h1 has right id';
		like $html, qr/<h2 id="secoend-level-heading">/, 'h2 has right id';
		};

	subtest 'headers-unicode unicode with dashes' => sub {
		my %options = (
			heading_ids_spaces_to_dash => 1,
			unicode_ids          => 1,
		);
		my $mm = $class->new( %options );
		isa_ok $mm, $class;
		can_ok $mm, $method;

		ok exists  $Snippets{'headers-unicode'}, 'headers snippet exists';
		my $html = $mm->markdown( $Snippets{'headers-unicode'},
			{ heading_ids_spaces_to_dash => 1, transliterate_ids => 1 }  );
		like $html, qr/<h1 id="firşt-lévål-heaðing">/,  'h1 has right id';
		like $html, qr/<h2 id="sęcœñd-łevel-heädıng">/, 'h2 has right id';
		};

	subtest 'links' => sub {
		ok exists  $Snippets{links}, 'links snippet exists';


		};
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
		is Text::MultiMarkdown::_default_id_handler( $input ),         $ascii,    'ASCII label';
		is Text::MultiMarkdown::_unicode_id_handler( $input ),         $unicode,  'unicode label';
		SKIP: {
			skip "need Text::Unidecode to test transliteration", 1 unless $has_unidecode;
			is Text::MultiMarkdown::_transliteration_id_handler( $input ), $translit, 'transliteration label';
			}
		};
}

sub get_snippets {
	my $data = do { local $/; <DATA> };

	my @splits = split /^@@\h+/m, $data;
	shift @splits;

	my %Snippets = map {
		my( $name, $data ) = split m/\h*\R/, $_, 2;
		$name =~ s/\A\s+|\s+\z//g;
		$data =~ s/\A\s+|\s+\z//g;
		( $name, $data );
		} @splits;

	return %Snippets;
}

done_testing;

__END__
@@ headers-ascii
# First level heading

Some text

## Second level heading

@@ headers-unicode

# Firşt lévål heaðing

Some text

## Sęcœñd łevel heädıng

@@ links

[foo](fee-fie-foo-fum.html)
