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

	my @table = (
		{
		label        => 'headers-ascii',
		snippet_name => 'headers-ascii',
		h1_pattern   => qr/<h1 id="firstlevelheading">/,
		h2_pattern   => qr/<h2 id="secondlevelheading">/,
		options      => {},
		},

		{
		label        => 'headers-unicode legacy',
		snippet_name => 'headers-unicode',
		h1_pattern   => qr/<h1 id="firtlvlheaing">/,
		h2_pattern   => qr/<h2 id="scdevelhedng">/,
		options      => {},
		},

		{
		label        => 'headers-unicode legacy with dashes',
		snippet_name => 'headers-unicode',
		h1_pattern   => qr/<h1 id="firt-lvl-heaing">/,
		h2_pattern   => qr/<h2 id="scd-evel-hedng">/,
		options      => {
			heading_ids_spaces_to_dash => 1,
			},
		},

		{
		label        => 'headers-unicode legacy with dashes',
		snippet_name => 'headers-unicode',
		h1_pattern   => qr/<h1 id="firt-lvl-heaing">/,
		h2_pattern   => qr/<h2 id="scd-evel-hedng">/,
		options      => {
			heading_ids_spaces_to_dash => 1,
			},
		},

		{
		label        => 'headers-unicode transliteration with dashes',
		snippet_name => 'headers-unicode',
		h1_pattern   => qr/<h1 id="first-leval-heading">/,
		h2_pattern   => qr/<h2 id="secoend-level-heading">/,
		options      => {
			heading_ids_spaces_to_dash => 1,
			transliterate_ids          => 1,
			},
		},

		{
		label        => 'headers-unicode unicode transliterate with dashes',
		snippet_name => 'headers-unicode',
		h1_pattern   => qr/<h1 id="firşt-lévål-heaðing">/,
		h2_pattern   => qr/<h2 id="sęcœñd-łevel-heädıng">/,
		warning_from_new => qr/ignoring transliterate_ids/,
		options      => {
			heading_ids_spaces_to_dash => 1,
			transliterate_ids          => 1,
			unicode_ids                => 1,
			},
		},

		{
		label        => 'headers-unicode unicode with dashes',
		snippet_name => 'headers-unicode',
		h1_pattern   => qr/<h1 id="firşt-lévål-heaðing">/,
		h2_pattern   => qr/<h2 id="sęcœñd-łevel-heädıng">/,
		options      => {
			heading_ids_spaces_to_dash => 1,
			unicode_ids                => 1,
			},
		},

		);

	foreach my $row ( @table ) {
		subtest $row->{label} => sub {
			ok exists $Snippets{ $row->{snippet_name} }, 'headers snippet exists';
			my $text = $Snippets{ $row->{snippet_name} };

			subtest 'method' => sub {
				my $mm = do {
					my $warnings;
					local $SIG{__WARN__} = sub { $warnings .= join "\n", @_; };
					my $mm = $class->new( %{ $row->{options} } );
					if ( $row->{warning_from_new} ) {
						like $warnings, $row->{warning_from_new}, 'warning from new';
						}
					$mm;
					};
				isa_ok $mm, $class;
				can_ok $mm, $method;

				foreach my $method ( qw(markdown to_html) ) {
					subtest $method => sub {
						my $html = $mm->$method( $text );
						like $html, $row->{h1_pattern}, 'h1 has right id';
						like $html, $row->{h2_pattern}, 'h2 has right id';
						};
					}
				};


			subtest 'markdown function' => sub {
				my $html = Text::MultiMarkdown::markdown( $text, $row->{options} );
				like $html, $row->{h1_pattern}, 'h1 has right id';
				like $html, $row->{h2_pattern}, 'h2 has right id';
				};

			subtest 'multimardown_to_html function' => sub {
				my $html = Text::MultiMarkdown::multimarkdown_to_html( $text, $row->{options} );
				like $html, $row->{h1_pattern}, 'h1 has right id';
				like $html, $row->{h2_pattern}, 'h2 has right id';
				};
			};
		}
	};

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
