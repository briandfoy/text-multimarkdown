use strict;
use warnings;
use Test::More;

my $class = 'Text::MultiMarkdown';
my @methods = qw(markdown to_html);

subtest 'sanity' => sub {
	use_ok($class) or BAIL_OUT( "Could not compile $class: Stopping" );
	can_ok $class, @methods;
	};

my @table = (
	{ # XXX: 04-markdown
	label    => 'plain text - no ending newline',
	markdown => "Foo\n\nBar",
	options  => {},
	expected_html => "<p>Foo</p>\n\n<p>Bar</p>\n",
	},

	{ # XXX: 04-markdown
	label    => 'plain text - ending newline',
	markdown => "Foo\n\nBar\n",
	options  => {},
	expected_html => "<p>Foo</p>\n\n<p>Bar</p>\n",
	},

	{
	label    => 'empty link',
	markdown => '[test][] the link!',
	options  => {},
	expected_html => "<p>[test][] the link!</p>\n",
	},

	{
	label    => 'empty link with urls option',
	markdown => '[test][] the link!',
	options  => {urls => {test => 'http://example.com'}},
	expected_html => qq(<p><a href="http://example.com">test</a> the link!</p>\n),
	},

	{
	label    => 'wikiword no metadata',
	markdown => 'A trivial block of text with a WikiWord',
	options  => {use_wikilinks => 1},
	expected_html => qq(<p>A trivial block of text with a <a href="WikiWord">WikiWord</a></p>\n),
	},

	{
	label    => 'wikiword with base_url',
	markdown => 'A trivial block of text with a WikiWord',
	options  => {
		use_wikilinks => 1,
		base_url      => 'http://www.test.com/',
		},
	expected_html => qq(<p>A trivial block of text with a <a href="http://www.test.com/WikiWord">WikiWord</a></p>\n),
	},

	{ # 09-base_url
	label    => 'wikiword with use_metadata',
	markdown => "base url: http://www.test.com/\n\nA trivial block of text with a WikiWord",
	options  => {
		use_wikilinks => 1,
		use_metadata  => 1,
		},
	expected_html => qq(base url: http://www.test.com/<br />\n\n<p>A trivial block of text with a <a href="http://www.test.com/WikiWord">WikiWord</a></p>\n),
	},

	);

subtest 'expected html' => sub {
	foreach my $row ( @table ) {
		subtest $row->{label} => sub {
			subtest 'instance method' => sub {
				my $m = $class->new;
				isa_ok $m, $class;
				can_ok $m, @methods;

				foreach my $method ( @methods ) {
					my $html = $m->$method($row->{markdown}, $row->{options});
					is $html, $row->{expected_html}, "$method returns expected HTML";

					if ( keys %{ $row->{options} } == 0 ) {
						my $html = $m->$method($row->{markdown});
						is $html, $row->{expected_html}, "$method returns expected HTML";
						}
					}
				};

			subtest 'class method' => sub {
				can_ok $class, @methods;

				foreach my $method ( @methods ) {
					my $html = $class->$method($row->{markdown}, $row->{options});
					is $html, $row->{expected_html}, "$method returns expected HTML";

					if ( keys %{ $row->{options} } == 0 ) {
						my $html = $class->$method($row->{markdown});
						is $html, $row->{expected_html}, "$method returns expected HTML";
						}
					}
				};

			subtest 'functions' => sub {
				my @functions = map { [ $_, $class->can($_) ] } qw(markdown multimarkdown_to_html);

				foreach my $item ( @functions ) {
					my( $label, $function ) = @$item;
					subtest $label => sub {
						my $html = $function->($row->{markdown}, $row->{options});
						is $html, $row->{expected_html}, "$label returns expected HTML";

						if ( keys %{ $row->{options} } == 0 ) {
							my $html = $function->($row->{markdown});
							is $html, $row->{expected_html}, "$label returns expected HTML";
							}
						};
					}
				};
			};
		}
	};


done_testing();
