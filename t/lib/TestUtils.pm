package TestUtils;
use warnings;
use strict;

use Exporter qw(import);
our @EXPORT = qw(difftest get_files run_tests slurp tidy);

use Encode;
use File::Spec::Functions qw(catfile);
use List::MoreUtils qw(uniq);
use Test::More;

our $TIDY = eval { require HTML::Tidy };

BEGIN {
	eval { require Text::Diff; };
	if (!$@) {
		*difftest = sub {
			my ($got, $expected, $testname) = @_;
			$got .= "\n";
			$expected .= "\n";
			if ($got eq $expected) {
				pass($testname);
				return 1;
			}
			print STDERR "=" x 80 . "\nTest <$testname> DIFFERENCES: + = processed version from .text, - = template from .html\n";
			print STDERR encode('utf8', Text::Diff::diff(\$expected => \$got, { STYLE => "Unified" }) . "\n");
			fail($testname);
			return 0;
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

    FILE: foreach my $test (@files) {
    	subtest "file: $test" => sub {
			my( $expected_output_filename ) =
				grep { -f }
				map { catfile $docsdir, "$test.$_" }
				qw(html xhtml);
			unless (-e $expected_output_filename) {
				fail( "Expected output file <$expected_output_filename> does not exist" );
				return;
				}
			my $expected_output = slurp($expected_output_filename);
			$expected_output =~ s/[\x20\t]+$//gm;
			$expected_output =~ s/\s+\z//;

			my( $input_filename ) = catfile $docsdir, "$test.text";
			ok -e $input_filename, "input file <$input_filename> exists";
			my $input = slurp($input_filename);

			my $html = $m->markdown($input);
			$html =~ s/[\x20\t]+$//gm;
			$html =~ s/\s+\z//;

			if ($TIDY) {
				local $SIG{__WARN__} = sub {};
				my $t = HTML::Tidy->new;
				$expected_output = $t->clean($expected_output);
				$html = $t->clean($html);
			}

			difftest($html, $expected_output, "Docs test: $test");
			};
		}
	}

sub slurp {
    my ($filename) = @_;
    open my $file, '<:utf8', $filename or die "Couldn't open $filename: $!";
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
