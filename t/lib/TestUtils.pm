package TestUtils;
use Exporter qw(import);
@EXPORT = qw(difftest get_files run_tests slurp tidy);

use Encode;
use List::MoreUtils qw(uniq);
use Test::More;

BEGIN {
	eval {
		require Text::Diff;
	};
	if (!$@) {
		*difftest = sub {
			my ($got, $expected, $testname) = @_;
			$got .= "\n";
			$expected .= "\n";
			if ($got eq $expected) {
				pass($testname);
				return;
			}
			print "=" x 80 . "\nDIFFERENCES: + = processed version from .text, - = template from .html\n";
			print encode('utf8', Text::Diff::diff(\$expected => \$got, { STYLE => "Unified" }) . "\n");
			fail($testname);
		};
	}
	else {
		warn("Install Text::Diff for more helpful failure messages! ($@)");
		*difftest = \&Test::More::is;
	}
}
sub get_files {
    my ($docsdir) = @_;
    my $DH;
    opendir($DH, $docsdir) or die("Could not open $docsdir");
    my @files = uniq map { s/\.(xhtml|html|text)$// ? $_ : (); } readdir($DH);
    closedir($DH);
    return @files;
}

sub run_tests {
    my ($m, $docsdir, @files) = @_;
    foreach my $test (@files) {
        my ($input, $output);
        eval {
            if (-f "$docsdir/$test.html") {
                $output = slurp("$docsdir/$test.html");
            }
            else {
                $output = slurp("$docsdir/$test.xhtml");
            }
            $input  = slurp("$docsdir/$test.text");
        };
        $input .= "\n\n";
        $output .= "\n\n";
        if ($@) {
            fail("1 part of test file not found: $@");
            next;
        }
        $output =~ s/\s+\z//; # trim trailing whitespace
        my $processed = $m->markdown($input);
        $processed =~ s/\s+\z//; # trim trailing whitespace

        if ($TIDY) {
            local $SIG{__WARN__} = sub {};
            my $t = HTML::Tidy->new;
            $output = $t->clean($output);
            $processed = $t->clean($processed);
        }

        # Un-comment for debugging if you have space diffs you can't see..
        $output =~ s/ /&nbsp;/g;
        $output =~ s/\t/&tab;/g;
        $processed =~ s/ /&nbsp;/g;
        $processed =~ s/\t/&tab;/g;

        difftest($processed, $output, "Docs test: $test");
    }
}

sub slurp {
    my ($filename) = @_;
    open my $file, '<', $filename or die "Couldn't open $filename: $!";
    local $/ = undef;
    return <$file>;
}

sub tidy {
    eval "use HTML::Tidy;";
    if ($@) {
        plan skip_all => 'This test needs HTML::Tidy installed to pass correctly, skipping';
    }
}

1;
