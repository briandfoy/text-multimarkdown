use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);

use lib qq($Bin/lib);
use TestUtils;

my $class = 'Text::MultiMarkdown';
my @methods = qw(new markdown to_html);

subtest 'sanity' => sub {
	use_ok($class) or BAIL_OUT( "Could not compile $class: Stopping" );
	can_ok $class, @methods;
	};

subtest 'fenced' => sub {
	my $m = Text::MultiMarkdown->new;
	isa_ok $m, $class;

	my $markdown = <<'MARKDOWN';
This is a body line.

```
#!/usr/bin/perl

print "Hello world\n";

```

This is another body line.
MARKDOWN


	my $expected = <<'HTML';
<p>This is a body line.</p>

<pre><code>
#!/usr/bin/perl

print "Hello world\n";
</code></pre>

<p>This is another body line.</p>

HTML

	my $got = $m->to_html($markdown);

	is $got, $expected, 'fenced output is correct';
	};

done_testing();
