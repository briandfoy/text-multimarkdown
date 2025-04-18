require 5.008_000;
use utf8;

package Text::MultiMarkdown;
use strict;
use warnings;
use re 'eval';

use Digest::MD5    qw(md5_hex);
use Encode         qw();
use Carp           qw(carp croak);
use base           qw(Text::Markdown);
use HTML::Entities qw(encode_entities);
use Scalar::Util   qw(blessed);
use Unicode::Normalize ();

our $VERSION   = '1.005';
our @EXPORT_OK = qw(markdown multimarkdown_to_html);

=encoding utf8

=head1 NAME

Text::MultiMarkdown - Convert MultiMarkdown syntax to (X)HTML

=head1 SYNOPSIS

Use it as a function, with or without optional arguments:

    use Text::MultiMarkdown 'markdown';

    my $html = markdown($text);

    my $html = markdown( $text, {
        empty_element_suffix => '>',
        tab_width => 2,
        use_wikilinks => 1,
    } );

Or in the object-oriented interface:

    use Text::MultiMarkdown;

    my $m = Text::MultiMarkdown->new;
    my $html = $m->markdown($text);

    my $m = Text::MultiMarkdown->new(
        empty_element_suffix => '>',
        tab_width => 2,
        use_wikilinks => 1,
    );
    my $html = $m->markdown( $text );

=head1 DESCRIPTION

Markdown is a text-to-HTML filter; it translates an easy-to-read /
easy-to-write structured text format into HTML. Markdown's text format
is most similar to that of plain text email, and supports features such
as headers, *emphasis*, code blocks, blockquotes, and links.

Markdown's syntax is designed not as a generic markup language, but
specifically to serve as a front-end to (X)HTML. You can use span-level
HTML tags anywhere in a Markdown document, and you can use block level
HTML tags (C<< <div> >>, C<< <table> >> etc.). Note that by default
Markdown isn't interpreted in HTML block-level elements, unless you add
a C<markdown="1"> attribute to the element. See L<Text::Markdown> for
details.

This module implements the MultiMarkdown markdown syntax extensions from:

    http://fletcherpenney.net/multimarkdown/

=head1 SYNTAX

For more information about (original) Markdown's syntax, see:

    http://daringfireball.net/projects/markdown/

This module implements MultiMarkdown, which is an extension to Markdown..

The extension is documented at:

    http://fletcherpenney.net/multimarkdown/

and borrows from php-markdown, which lives at:

    http://michelf.com/projects/php-markdown/extra/

This documentation is going to be moved/copied into this module for
clearer reading in a future release..

=head2 Options

MultiMarkdown supports a number of options to its processor which
control the behaviour of the output document.

These options can be supplied to the constructor, on in a hash with
the individual calls to the markdown method. See the synopsis for
examples of both of the above styles.

The options for the processor are:

=over 4

=item bibliography_title

The title of the generated bibliography, defaults to 'Bibliography'.

=item disable_bibliography

If true, this disables the MultiMarkdown bibliography/citation handling.

=item disable_definition_lists

If true, this disables the MultiMarkdown definition list handling.

=item disable_footnotes

If true, this disables the MultiMarkdown footnotes handling.

=item disable_tables

If true, this disables the MultiMarkdown table handling.

=item empty_element_suffix

This option can be used to generate normal HTML output. By default, it
is C<< /> >>, which is xHTML, change to C<< > >> for normal HTML.

=item heading_ids

Controls if C<hX> tags generated have an id attribute. Defaults to true.
Turn off for compatibility with the original markdown.

=item heading_ids_spaces_to_dash

Controls whether spaces in headings should be rendered as "-" characters
in the heading ids (for compatibility with GitHub markdown, and others)

=item img_ids

Controls if C<img> tags generated have an id attribute. Defaults to true.
Turn off for compatibility with the original markdown.

=item strip_metadata

If true, any metadata in the input document is removed from the output
document (note - does not take effect in complete document format).

=item tab_width

Controls indent width in the generated markup, defaults to 4

=item transliterated_ids

In markdown label values, change accented and other non-ASCII letter
characters with L<Text::Unidecode>. If that module is not available,
this issues a warning and does nothing. When C<unicode_ids> is true,
this is ignored. The default is false.

=item unicode_ids

In markdown label values, allow any Unicode letter character along
with the allowed ASCII symbol characters. This overrules
C<transliterated_ids> when true. The default is false.

=item use_metadata

Controls the metadata options below.

=back

=head2 Metadata

MultiMarkdown supports the concept of 'metadata', which allows you to
specify a number of formatting options within the document itself.
Metadata should be placed in the top few lines of a file, on value per
line as colon separated key/value pairs. The metadata should be
separated from the document with a blank line.

Most metadata keys are also supported as options to the constructor,
or options to the markdown method itself. (Note, as metadata, keys
contain space, whereas options the keys are underscore separated.)

You can attach arbitrary metadata to a document, which is output in
HTML C<< <META> >> tags if unknown, see F<t/11-document_format.t> for
an example.

These are the known metadata keys:

=over 4

=item document_format

If set to 'complete', MultiMarkdown will render an entire xHTML page,
otherwise it will render a document fragment

=over 4

=item base url

This is the base URL for referencing wiki pages. In this is not
supplied, all wiki links are relative.

=item css

Sets a CSS file for the file, if in 'complete' document format.

=item title

Sets the page title, if in 'complete' document format.

=back

=item use wikilinks

If set to '1' or 'on', causes links that are WikiWords to
automatically be processed into links.

=back

=head2 Class methods

=over 4

=item new

A simple constructor, see the SYNTAX and OPTIONS sections for more information.

=cut

my %defaults;
BEGIN {
%defaults = (
	use_metadata               => 1,
	base_url                   => '',
	tab_width                  => 4,
	document_format            => '',
	empty_element_suffix       => ' />',
	use_wikilinks              => 0,
	heading_ids                => 1,
	img_ids                    => 1,
	bibliography_title         => 'Bibliography',
	self_url                   => '',
	heading_ids_spaces_to_dash => '',
	);

}

sub new {
    my ($class, %args) = @_;

	my %p = ( %defaults, %args );

	my @binary = qw(use_metadata use_wikilinks);
	$p{$_} = $p{$_} ? 1 : 0 for @binary;

	unless( $p{tab_width} =~ m/^[0-9]+$/ ) {
		carp "tab_width did not look like a decimal number, so using the default 4";
		$p{tab_width} = 4;
	}

	_process_id_handler( \%args, \%p );

    my $self = { params => \%p };
    bless $self, ref($class) || $class;
    return $self;
}

sub _id_handler {
	defined $_[0]->{id_handler} ? $_[0]->{id_handler} : \&_default_id_handler
}

sub _default_id_handler {
	my ($label) = @_;

	$label =~ s/[^A-Za-z0-9:_.-]//g;
	$label =~ s/\A[^A-Za-z]+//g;
	$label =~ s/-+/-/g;
	$label =~ s/-+\z//g;

	return $label;
}

BEGIN {
my $has_unidecode = eval { require Text::Unidecode };

sub _transliteration_id_handler {
	my ($label) = @_;

	unless ($has_unidecode ) {
		carp "Need Text::Unidecode to for transliterated_ids, but could not load it. Falling back to default id handler";
		return _default_id_handler($label);
	}

	$label = Text::Unidecode::unidecode($label);

	$label =~ s/\s+//g;
	$label =~ s/\A[^A-Za-z]+//g;
	$label =~ s/-+/-/g;
	$label =~ s/-+\z//g;

	return $label;
}

{
no warnings qw(redefine);
*_transliteration_id_handler = \&_default_id_handler unless $has_unidecode;
}

sub _unicode_id_handler {
	my ($label) = @_;

	$label =~ s/\s+//g;
	$label =~ s/\W+/-/g;
	$label =~ s/\A\P{Letter}+//g;
	$label =~ s/-+/-/g;
	$label =~ s/-+\z//g;
	return $label;
}

sub _process_id_handler {
	my( $args, $p ) = @_;

	$p->{id_handler} = \&_default_id_handler;

	if ( exists $args->{unicode_ids} and $args->{unicode_ids} and exists $args->{transliterated_ids} ) {
		warn "ignoring transliterated_ids because unicode_ids is true\n";
		delete $args->{transliterated_ids};
		}

	if ( $args->{unicode_ids} ) {
		$p->{id_handler} = \&_unicode_id_handler
		}
	elsif ( $args->{transliterated_ids} ) {
		warn "Need Text::Unidecode to transliterate labels, but could not load it\n"
			unless $has_unidecode;
		$p->{id_handler} = \&_transliteration_id_handler;
		}
	}
}

=back

=head2 Instance methods

=over 4

=item markdown( MARKDOWN_TEXT [, HASHREF] )

This is the legacy interface to this module, but it does too much and
is a poor name. For the function form, use C<multimarkdown_to_html>
instead. At the moment that's just a wrapper for C<markdown> in the
functional form. For the object-oriented forms, use C<to_html> instead.
That's also just a wrapper for this, but will later change to enforce
object-orientedness (i.e. exclude the functional form).

And now the legacy stuff.

This works as either a class method, instance method, or exportable
function:

	my $html = Text::MultiMarkdown->markdown( $text );

	my $mm = Text::MultiMarkdown->new;
	my $html = $mm->markdown($text);

	use Text::MultiMarkdown qw(markdown);
	my $html = markdown( $text );

Any of these forms take an optional HASH_REF argument for options. These
are the options for this module or the parent class L<Text::Markdown>:

	my $html = Text::MultiMarkdown->markdown( $text, { ... } );

	my $mm = Text::MultiMarkdown->new;
	my $html = $mm->markdown($text, { ... });

	use Text::MultiMarkdown qw(markdown);
	my $html = markdown( $text, { ... } );

To make this work in all these cases, since this was the legacy design,
various unsavory things have to happen.

When called as a class method, a new object is constructed. We guess
that it's a class method by looking at the first argument and seeing
that it looks like a Perl package name. In prior versions this was
documented to not work, but there was also a TODO test for it to work.
So, now it works. This might fail if the entire markdown text is exactly
a valid Perl package name.

If the first argument is a blessed reference, we guess that this is
an instance method. With the optional HASH_REF argument this constructs
a new argument with all of the settings of the original object and the
stuff in HASH_REF. This might fail if you have some weird case where
you call this as a function but pass as the TEXT argument an object that
has overloaded stringification .

=cut

=begin comment

=end comment

There are these situations:

	CLASS->markdown( TEXT );
	CLASS->markdown( TEXT, HASHREF );

	OBJ->markdown( TEXT );
	OBJ->markdown( TEXT, HASHREF );

	markdown( TEXT );
	markdown( TEXT, HASHREF );

These are really:

	markdown( CLASS, TEXT )
	markdown( CLASS, TEXT, HASHREF )

	markdown( OBJ, TEXT )
	markdown( OBJ, TEXT, HASHREF )

	markdown( TEXT );
	markdown( TEXT, HASHREF );

Which breaks down to these groups:

	1) markdown( TEXT );

	2.1) markdown( TEXT, HASHREF );
	2.2) markdown( CLASS, TEXT )
	2.3) markdown( OBJ, TEXT )

	3.1) markdown( CLASS, TEXT, HASHREF )
	3.2) markdown( OBJ, TEXT, HASHREF )

In 1), 2.2), and 3.1), we should make a new object and then do our
thing.

In 3.1), the previous version specifically said that we can't call
this as a class method.

In 3.2), we need to merge the options in the existing object with
the new options. This was never a documented feature though.

Part of the tickyness is that interface for Text::Markdown. We need
to pass the HASHREF to _CleanUpRunData in the SUPER class

=cut

sub _looks_like_class {
	local $_ = $_[0];
	m/\A\w+(?:::\w+)+\z/;
}

sub markdown {
	my( $self, $text, $options ) = do {
		if ( @_ == 1 and ! ref $_[0] ) { # Case 1
			( __PACKAGE__->new, $_[0], {} );
		} elsif ( @_ == 2 and ! _looks_like_class($_[0]) and ref $_[1] eq ref {} ) { # Case 2.1
			( __PACKAGE__->new( %{ $_[1] } ), $_[0], $_[1] );
		} elsif ( @_ == 2 and _looks_like_class($_[0]) and ! ref $_[1] ) { # Case 2.2
			( $_[0]->new, $_[1] );
		} elsif ( @_ == 2 and blessed($_[0]) and ! ref $_[1] ) { # Case 2.3
			( $_[0], $_[1], {} );
		} elsif ( @_ == 3 and _looks_like_class($_[0]) and ! ref $_[1] and ref $_[2] eq ref {} ) { # Case 3.1
			( $_[0]->new( %{ $_[2]} ), $_[1], $_[2] );
		} elsif ( @_ == 3 and blessed($_[0]) and ! ref $_[1] and ref $_[2] eq ref {} ) { # Case 3.2
			my %merged = ( %{ $_[0]->{params} }, %{ $_[2] } );
			my $new = $_[0]->new( %merged );
			( $new, $_[1], $_[2] );
		} else {
			carp "Unrecognized arguments for markdown()";
			return;
		}
	};

    $options = {} unless defined $options;

	%$self = (%{ $self->{params} }, %$options, params => $self->{params});
	$self->_CleanUpRunData($options);

    return $self->_Markdown($text);
}

=item multimarkdown_to_html

For the functional interface, you should use this instead of C<markdown>
because it's a better name. At the moment it's the same as calling
C<markdown>, but eventually this will diverge from the object-oriented
form C<to_html>, which is also a better name.

=cut

sub multimarkdown_to_html {
	markdown(@_);
}

=item to_html

As a class or instance method, you should use this instead of C<markdown>
because it's a better name. At the moment it's the same as calling
C<markdown>, but eventually this will diverge from the functional
form C<multimarkdown_to_html>, which is also a better name.

=cut

sub to_html {
	markdown(@_);
}

sub _CleanUpRunData {
    my ($self, $options) = @_;
    # Clear the global hashes. If we don't clear these, you get conflicts
    # from other articles when generating a page which contains more than
    # one article (e.g. an index page that shows the N most recent
    # articles):
    $self->{_crossrefs}   = {};
    $self->{_footnotes}   = {};
    $self->{_references}  = {};
    $self->{_used_footnotes}  = []; # Why do we need 2 data structures for footnotes? FIXME
    $self->{_used_references} = []; # Ditto for references
    $self->{_citation_counter} = 0;
    $self->{_metadata} = {};
    $self->{_attributes}  = {}; # Used for extra attributes on links / images.

    $self->SUPER::_CleanUpRunData($options);
}

sub _Markdown {
#
# Main function. The order in which other subs are called here is
# essential. Link and image substitutions need to happen before
# _EscapeSpecialChars(), so that any *'s or _'s in the <a>
# and <img> tags get encoded.
#
# Can't think of any good way to make this inherit from the Markdown version as ordering is so important, so I've left it.
    my ($self, $text) = @_;

    $text = $self->_CleanUpDoc($text);

    # MMD only. Strip out MetaData
    $text = $self->_ParseMetaData($text) if ($self->{use_metadata} || $self->{strip_metadata});

    # Turn block-level HTML blocks into hash entries
    $text = $self->_HashHTMLBlocks($text, {interpret_markdown_on_attribute => 1});

    $text = $self->_StripLinkDefinitions($text);

    # MMD only
    $text = $self->_StripMarkdownReferences($text);

    $text = $self->_RunBlockGamut($text, {wrap_in_p_tags => 1});

    # MMD Only
    $text = $self->_DoMarkdownCitations($text) unless $self->{disable_bibliography};
    $text = $self->_DoFootnotes($text) unless $self->{disable_footnotes};

    $text = $self->_UnescapeSpecialChars($text);

    # MMD Only
    # This must follow _UnescapeSpecialChars
    $text = $self->_UnescapeWikiWords($text);
    $text = $self->_FixFootnoteParagraphs($text) unless $self->{disable_footnotes};  # TODO: remove. Doesn't make any difference to test suite pass/failure
    $text .= $self->_PrintFootnotes() unless $self->{disable_footnotes};
    $text .= $self->_PrintMarkdownBibliography() unless $self->{disable_bibliography};

    $text = $self->_ConvertCopyright($text);

    # MMD Only
    if (lc($self->{document_format}) =~ /^complete\s*$/) {
        return $self->_xhtmlMetaData() . "<body>\n" . $text . "\n</body>\n</html>";
    }
    else {
        return $self->_textMetaData() . $text . "\n";
    }

}

#
# Routines which are overridden for slightly different behaviour in MultiMarkdown
#

# Delegate to super class, then do wiki links
sub _RunSpanGamut {
    my ($self, $text) = @_;

    $text = $self->SUPER::_RunSpanGamut($text);

    # Process WikiWords
    if ($self->_UseWikiLinks()) {
        $text = $self->_DoWikiLinks($text);

        # And then reprocess anchors and images
        # FIXME - This is needed exactly why?
        $text = $self->_DoImages($text);
        $text = $self->_DoAnchors($text);
    }

    return $text;
}

# Don't do Wiki Links in Headers, otherwise delegate to super class
# Do tables stright after headers
sub _DoHeaders {
    my ($self, $text) = @_;

    local $self->{use_wikilinks} = 0;

    $text = $self->SUPER::_DoHeaders($text);

    # Do tables to populate the table id's for cross-refs
    # (but after headers as the tables can contain cross-refs to other things, so we want the header cross-refs)
    $text = $self->_DoTables($text);
}

sub _DoLists {
    my ($self, $text) = @_;
    $text = $self->_DoDefinitionLists($text)
        unless $self->{disable_definition_lists};
    $self->SUPER::_DoLists($text);
}

sub _DoDefinitionLists {
    my ($self, $text) = @_;
	# Uses the syntax proposed by Michel Fortin in PHP Markdown Extra

	my $less_than_tab = $self->{tab_width} -1;

	my $line_start = qr{
		[ ]{0,$less_than_tab}
	}mx;

	my $term = qr{
		$line_start
		[^:\s][^\n]*\n
	}sx;

	my $definition = qr{
		\n?[ ]{0,$less_than_tab}
		\:[ \t]+(.*?)\n
		((?=\n?\:)|\n|\Z)	# Lookahead for next definition, two returns,
							# or the end of the document
	}sx;

	my $definition_block = qr{
		((?:$term)+)				# $1 = one or more terms
		((?:$definition)+)			# $2 = by one or more definitions
	}sx;

	my $definition_list = qr{
		(?:$definition_block\n*)+		# One ore more definition blocks
	}sx;

	$text =~ s{
		($definition_list)			# $1 = the whole list
	}{
		my $list = $1;
		my $result = $1;

		$list =~ s{
			(?:$definition_block)\n*
		}{
			my $terms = $1;
			my $defs = $2;

			$terms =~ s{
				[ ]{0,$less_than_tab}
				(.*)
				\s*
			}{
				my $term = $1;
				my $result = "";
				$term =~ s/^\s*(.*?)\s*$/$1/;
				if ($term !~ /^\s*$/){
					$result = "<dt>" . $self->_RunSpanGamut($1) . "</dt>\n";
				}
				$result;
			}xmge;

			$defs =~ s{
				$definition
			}{
				my $def = $1 . "\n";
				$def =~ s/^[ ]{0,$self->{tab_width}}//gm;
				"<dd>\n" . $self->_RunBlockGamut($def) . "\n</dd>\n";
			}xsge;

			$terms . $defs . "\n";
		}xsge;

		"<dl>\n" . $list . "</dl>\n\n";
	}xsge;

	return $text
}

# Generating headers automatically generates X-refs in MultiMarkdown (always)
# Also, by default, you get id attributes added to your headers, you can turn this
# part of the MultiMarkdown behaviour off with the heading_ids flag.
sub _GenerateHeader {
    my ($self, $level, $id) = @_;

    my $label = $self->{heading_ids} ? $self->_Header2Label($id) : '';
    my $header = $self->_RunSpanGamut($id);

    if ($label ne '') {
        $self->{_crossrefs}{$label} = "#$label";
        $self->{_titles}{$label} = $header;
        $label = qq{ id="$label"};
    }

    return "<h$level$label>$header</h$level>\n\n";
}

# Protect Wiki Links in Code Blocks (if wiki links are turned on), then delegate to super class.
sub _EncodeCode {
    my ($self, $text) = @_;

    if ($self->_UseWikiLinks()) {
        $text =~ s/([A-Z]+[a-z\x80-\xff]+[A-Z][A-Za-z\x80-\xff]*)/\\$1/gx;
    }

    return $self->SUPER::_EncodeCode($text);
}

# Full function pulled out of Text::Markdown as MultiMarkdown supports supplying extra 'attributes' with links and
#  images which are then pushed back into the generated HTML, and this needs a different regex. It should be possible
#  to extract the just the regex from Text::Markdown, and use that here, but I haven't done so yet.
# Strip footnote definitions at the same time as stripping link definitions.
# Also extract images and then replace them straight back in (code smell!) to be able to cross reference images
sub _StripLinkDefinitions {
#
# Strips link definitions from text, stores the URLs and titles in
# hash references.
#
    my ($self, $text) = @_;

    $text = $self->_StripFootnoteDefinitions($text) unless $self->{disable_footnotes};

    my $less_than_tab = $self->{tab_width} - 1;

    # Link defs are in the form: ^[id]: url "optional title"
    # FIXME - document attributes here.
    while ($text =~ s{
                        # Pattern altered for MultiMarkdown
                        # in order to not match citations or footnotes
                        ^[ ]{0,$less_than_tab}\[([^#^].*)\]:    # id = $1
                          [ \t]*
                          \n?                # maybe *one* newline
                          [ \t]*
                        <?(\S+?)>?            # url = $2
                          [ \t]*
                          \n?                # maybe one newline
                          [ \t]*
                        (?:
                            (?<=\s)            # lookbehind for whitespace
                            ["(]
                            (.+?)            # title = $3
                            [")]
                            [ \t]*
                        )?    # title is optional

                        # MultiMarkdown addition for attribute support
                        \n?
                        (                # Attributes = $4
                            (?<=\s)            # lookbehind for whitespace
                            (([ \t]*\n)?[ \t]*((\S+=\S+)|(\S+=".*?")))*
                        )?
                        [ \t]*
                        # /addition
                        (?:\n+|\Z)
                    }
                    {}mx) {
        $self->{_urls}{lc $1} = $self->_EncodeAmpsAndAngles( $2 );    # Link IDs are case-insensitive
        if ($3) {
            $self->{_titles}{lc $1} = $3;
            $self->{_titles}{lc $1} =~ s/"/&quot;/g;
        }

        # MultiMarkdown addition "
        if ($4) {
            $self->{_attributes}{lc $1} = $4;
        }
        # /addition
    }

    $text = $self->_GenerateImageCrossRefs($text);

    return $text;
}

# Add the extra cross-references to headers that MultiMarkdown supports, and also
# the additional link attributes.
sub _GenerateAnchor {
    # FIXME - Fugly, change to named params?
    my ($self, $whole_match, $link_text, $link_id, $url, $title, $attributes) = @_;

    # Allow automatic cross-references to headers
    if (defined $link_id) {
        my $label = $self->_Header2Label($link_id);
        if (defined $self->{_crossrefs}{$label}) {
            $url ||= $self->{_crossrefs}{$label};
        }
        if ( defined $self->{_titles}{$label} ) {
            $title ||= $self->{_titles}{$label};
        }
        $attributes ||= $self->_DoAttributes($label);
    }
    return $self->SUPER::_GenerateAnchor($whole_match, $link_text, $link_id, $url, $title, $attributes);
}

# Add the extra cross-references to images that MultiMarkdown supports, and also
# the additional attributes.
sub _GenerateImage {
    # FIXME - Fugly, change to named params?
    my ($self, $whole_match, $alt_text, $link_id, $url, $title, $attributes) = @_;

    if (defined $alt_text && length $alt_text) {
        my $label = $self->_Header2Label($alt_text);
        $self->{_crossrefs}{$label} = "#$label";
        $attributes .= $self->{img_ids} ? qq{ id="$label"} : '';
    }

    $attributes .= $self->_DoAttributes($link_id) if defined $link_id;

    $self->SUPER::_GenerateImage($whole_match, $alt_text, $link_id, $url, $title, $attributes);
}


#
# MultiMarkdown specific routines
#

# FIXME - This is really really ugly!
sub _ParseMetaData {
    my ($self, $text) = @_;
    my $clean_text = "";

    my ($inMetaData, $currentKey) = (1, '');

    foreach my $line ( split /\n/, $text ) {
        $line =~ /^\s*$/ and $inMetaData = 0 and $clean_text .= $line and next;
        if ($inMetaData) {
            next unless $self->{use_metadata}; # We can come in here as use_metadata => 0, strip_metadata => 1
            if ($line =~ /^([a-zA-Z0-9][0-9a-zA-Z _-]+?):\s*(.*)$/ ) {
                $currentKey = $1;
                $currentKey =~ s/  / /g;
                $self->{_metadata}{$currentKey} = defined $2 ? $2 : '';
                if (lc($currentKey) eq "format") {
                    $self->{document_format} = $self->{_metadata}{$currentKey};
                }
                if (lc($currentKey) eq "base url") {
                    $self->{base_url} = $self->{_metadata}{$currentKey};
                }
                if (lc($currentKey) eq "bibliography title") {
                    $self->{bibliography_title} = $self->{_metadata}{$currentKey};
                    $self->{bibliography_title} =~ s/\s*$//;
                }
            }
            else {
                if ($currentKey eq "") {
                    # No metadata present
                    $clean_text .= "$line\n";
                    $inMetaData = 0;
                    next;
                }
                if ($line =~ /^\s*(.+)$/ ) {
                    $self->{_metadata}{$currentKey} .= "\n$1";
                }
            }
        }
        else {
            $clean_text .= "$line\n";
        }
    }

    # Recheck for leading blank lines
    $clean_text =~ s/^\n+//s;

    return $clean_text;
}

# FIXME - This is really ugly, why do we match stuff and substitute it with the thing we just matched?
sub _GenerateImageCrossRefs {
    my ($self, $text) = @_;

    #
    # First, handle reference-style labeled images: ![alt text][id]
    #
    $text =~ s{
        (               # wrap whole match in $1
          !\[
            (.*?)       # alt text = $2
          \]

          [ ]?              # one optional space
          (?:\n[ ]*)?       # one optional newline followed by spaces

          \[
            (.*?)       # id = $3
          \]

        )
    }{
        my $whole_match = $1;
        my $alt_text    = $2;
        my $link_id     = lc $3;

        if ($link_id eq "") {
            $link_id = lc $alt_text;     # for shortcut links like ![this][].
        }

        $alt_text =~ s/"/&quot;/g;

        if (defined $self->{_urls}{$link_id}) {
            my $label = $self->_Header2Label($alt_text);
            $self->{_crossrefs}{$label} = "#$label";
        }

        $whole_match;
    }xsge;

    #
    # Next, handle inline images:  ![alt text](url "optional title")
    # Don't forget: encode * and _

    $text =~ s{
        (               # wrap whole match in $1
          !\[
            (.*?)       # alt text = $2
          \]
          \(            # literal paren
            [ \t]*
            <?(\S+?)>?  # src url = $3
            [ \t]*
            (           # $4
              (['"])    # quote char = $5
              (.*?)     # title = $6
              \5        # matching quote
              [ \t]*
            )?          # title is optional
          \)
        )
    }{
        my $result;
        my $whole_match = $1;
        my $alt_text    = $2;

        $alt_text =~ s/"/&quot;/g;
        my $label = $self->_Header2Label($alt_text);
        $self->{_crossrefs}{$label} = "#$label";
        $whole_match;
    }xsge;

    return $text;
}

sub _StripFootnoteDefinitions {
    my ($self, $text) = @_;
    my $less_than_tab = $self->{tab_width} - 1;

    while ($text =~ s{
      \n\[\^([^\n]+?)\]\:[ \t]*# id = $1
      \n?
      (.*?)\n{1,2}        # end at new paragraph
      ((?=\n[ ]{0,$less_than_tab}\S)|\Z)    # Lookahead for non-space at line-start, or end of doc
    }
    {\n}sx)
    {
        my $id = $1;
        my $footnote = "$2\n";
        $footnote =~ s/^[ ]{0,$self->{tab_width}}//gm;

        $self->{_footnotes}{$self->_Id2Footnote($id)} = $footnote;
    }

    return $text;
}

sub _DoFootnotes {
    my ($self, $text) = @_;

    return '' unless length $text;

    # First, run routines that get skipped in footnotes
    foreach my $label (sort keys %{ $self->{_footnotes} }) {
        my $footnote = $self->_RunBlockGamut($self->{_footnotes}{$label}, {wrap_in_p_tags => 1});
        $footnote = $self->_UnescapeSpecialChars($footnote);
        $footnote = $self->_DoMarkdownCitations($footnote);
        $self->{_footnotes}{$label} = $footnote;
    }

    my $footnote_counter = 0;

    $text =~ s{
        \[\^(.*?)\]     # id = $1
    }{
        my $result = '';
        my $id = $self->_Id2Footnote($1);

        if (defined $self->{_footnotes}{$id} ) {
            $footnote_counter++;
            if ($self->{_footnotes}{$id} =~ /^glossary:/i) {
                $result = qq{<a href="$self->{self_url}#fn:$id" id="fnref:$id" class="footnote glossary">$footnote_counter</a>};
            }
            else {
                $result = qq{<a href="$self->{self_url}#fn:$id" id="fnref:$id" class="footnote">$footnote_counter</a>};
            }
            push (@{ $self->{_used_footnotes} }, $id);
        }
        $result;
    }xsge;

    return $text;
}

# TODO: remove. Doesn't make any difference to test suite pass/failure
sub _FixFootnoteParagraphs {
    my ($self, $text) = @_;

    $text =~ s(^<p></footnote>)(</footnote>)gm;

    return $text;
}

sub _PrintFootnotes {
    my ($self) = @_;
    my $footnote_counter = 0;
    my $result;

    foreach my $id (@{ $self->{_used_footnotes} }) {
        $footnote_counter++;
        my $footnote = $self->{_footnotes}{$id};

        $footnote =~ s/(<\/(p(re)?|ol|ul)>)$//;
        my $footnote_closing_tag = $1;
        $footnote_closing_tag = '' if !defined $footnote_closing_tag;

        if ($footnote =~ s/^glossary:\s*//i) {
            # Add some formatting for glossary entries

            $footnote =~ s{
                ^(.*?)              # $1 = term
                \s*
                (?:\(([^\(\)]*)\)[^\n]*)?       # $2 = optional sort key
                \n
            }{
                my $glossary = qq{<span class="glossary name">$1</span>};

                if ($2) {
                    $glossary.= qq{<span class="glossary sort" style="display:none">$2</span>};
                };

                $glossary . q{:<p>};
            }egsx;

            $result .= qq{<li id="fn:$id">$footnote<a href="$self->{self_url}#fnref:$id" class="reversefootnote">&#160;&#8617;</a>$footnote_closing_tag</li>\n\n};
        }
        else {
            $result .= qq{<li id="fn:$id">$footnote<a href="$self->{self_url}#fnref:$id" class="reversefootnote">&#160;&#8617;</a>$footnote_closing_tag</li>\n\n};
        }
    }

    if ($footnote_counter > 0) {
        $result = qq[\n\n<div class="footnotes">\n<hr$self->{empty_element_suffix}\n<ol>\n\n] . $result . "</ol>\n</div>";
    }
    else {
        $result = "";
    }

    return $result;
}

sub _Header2Label {
    my ($self, $header) = @_;
    my $label = lc $header;
    $label =~ s/ +/-/g if $self->{heading_ids_spaces_to_dash};

	return $self->_id_handler->($label);
}

sub _Id2Footnote {
    # Since we prepend "fn:", we can allow leading digits in footnotes
    my ($self, $id) = @_;
    my $footnote = lc $id;
    $footnote =~ s/[^A-Za-z0-9:_.-]//g;     # Strip illegal characters
    return $footnote;
}

sub _xhtmlMetaData {
    my ($self) = @_;
    # FIXME: Should not assume encoding
    my $result; # FIXME: This breaks some things in IE 6- = qq{<?xml version="1.0" encoding="UTF-8" ?>\n};

    # This screws up xsltproc - make sure to use `-nonet -novalid` if you
    #   have difficulty
    $result .= qq{<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">\n};

    $result.= "<html>\n\t<head>\n";

    foreach my $key (sort keys %{$self->{_metadata}} ) {
        if (lc($key) eq "title") {
            $result.= "\t\t<title>" . encode_entities($self->{_metadata}{$key}) . "</title>\n";
        }
        elsif (lc($key) eq "css") {
            $result.= qq[\t\t<link type="text/css" rel="stylesheet" href="$self->{_metadata}{$key}"$self->{empty_element_suffix}\n];
        }
		elsif( lc($key) eq "xhtml header") {
			$result .= qq[\t\t$self->{_metadata}{$key}\n]
		}
        else {
            $result.= qq[\t\t<meta name="] . encode_entities($key) . qq[" ]
                . qq[content="] . encode_entities($self->{_metadata}{$key}) . qq["$self->{empty_element_suffix}\n];
        }
    }
    $result.= "\t</head>\n";

    return $result;
}

sub _textMetaData {
    my ($self) = @_;
    my $result = "";

    return $result if $self->{strip_metadata};

    foreach my $key (sort keys %{$self->{_metadata}} ) {
        $result .= "$key: $self->{_metadata}{$key}\n";
    }
    $result =~ s/\s*\n/<br$self->{empty_element_suffix}\n/g;

    if ($result ne "") {
        $result.= "\n";
    }

    return $result;
}

sub _UseWikiLinks {
    my ($self) = @_;
    return 1 if $self->{use_wikilinks};
    my ($k) = grep { /use wikilinks/i } keys %{$self->{_metadata}};
    return unless $k;
    return 1 if $self->{_metadata}{$k};
    return;
}

sub _CreateWikiLink {
    my ($self, $title) = @_;

    my $id = $title;
        $id =~ s/ /_/g;
        $id =~ s/__+/_/g;
        $id =~ s/^_//g;
        $id =~ s/_$//;

    $title =~ s/_/ /g;

    return "[$title](" . $self->{base_url} . "$id)";
}

sub _DoWikiLinks {

    my ($self, $text) = @_;
    my $WikiWord = '[A-Z]+[a-z\x80-\xff]+[A-Z][A-Za-z\x80-\xff]*';
    my $FreeLinkPattern = "([-,.()' _0-9A-Za-z\x80-\xff]+)";

    if ($self->_UseWikiLinks()) {
        # FreeLinks
        $text =~ s{
            \[\[($FreeLinkPattern)\]\]
        }{
            my $label = $1;
            $label =~ s{
                ([\s\>])($WikiWord)
            }{
                $1 ."\\" . $2
            }xsge;

            $self->_CreateWikiLink($label)
        }xsge;

        # WikiWords
        $text =~ s{
            ([\s])($WikiWord)
        }{
            $1 . $self->_CreateWikiLink($2)
        }xsge;

        # Catch WikiWords at beginning of text
        $text =~ s{^($WikiWord)
        }{
            $self->_CreateWikiLink($1)
        }xse;
    }


    return $text;
}

sub _UnescapeWikiWords {
    my ($self, $text) = @_;
    my $WikiWord = '[A-Z]+[a-z\x80-\xff]+[A-Z][A-Za-z\x80-\xff]*';

    # Unescape escaped WikiWords
    $text =~ s/(?<=\B)\\($WikiWord)/$1/g;

    return $text;
}

sub _DoTables {
    my ($self, $text) = @_;

    return $text if $self->{disable_tables};

    my $less_than_tab = $self->{tab_width} - 1;

    # Algorithm inspired by PHP Markdown Extra's
    # <http://www.michelf.com/projects/php-markdown/>

    # Reusable regexp's to match table

    my $line_start = qr{
        [ ]{0,$less_than_tab}
    }mx;

    my $table_row = qr{
        [^\n]*?\|[^\n]*?\n
    }mx;

    my $first_row = qr{
        $line_start
        \S+.*?\|.*?\n
    }mx;

    my $table_rows = qr{
        (\n?$table_row)
    }mx;

    my $table_caption = qr{
        $line_start
        \[.*?\][ \t]*\n
    }mx;

    my $table_divider = qr{
        $line_start
        [\|\-\:\.][ \-\|\:\.]* \| [ \-\|\:\.]*
    }mx;

    my $whole_table = qr{
        ($table_caption)?       # Optional caption
        ($first_row             # First line must start at beginning
        ($table_row)*?)?        # Header Rows
        $table_divider          # Divider/Alignment definitions
        $table_rows+            # Body Rows
        ($table_caption)?       # Optional caption
    }mx;


    # Find whole tables, then break them up and process them

    $text =~ s{
        ^($whole_table)         # Whole table in $1
        (\n|\Z)                 # End of file or 2 blank lines
    }{
        my $table = $1;
        my $result = "<table>\n";
        my @alignments;
        my $use_row_header = 0;

        # Add Caption, if present

        if ($table =~ s/^$line_start\[\s*(.*?)\s*\](\[\s*(.*?)\s*\])?[ \t]*$//m) {
            if (defined $3) {
                # add caption id to cross-ref list
                my $table_id = $self->_Header2Label($3);
                $result .= qq{<caption id="$table_id">} . $self->_RunSpanGamut($1). "</caption>\n";

                $self->{_crossrefs}{$table_id} = "#$table_id";
                $self->{_titles}{$table_id} = "$1";
            }
            else {
                $result .= "<caption>" . $self->_RunSpanGamut($1). "</caption>\n";
            }
        }

        # If a second "caption" is present, treat it as a summary
        # However, this is not valid in XHTML 1.0 Strict
        # But maybe in future

        # A summary might be longer than one line
        if ($table =~ s/\n$line_start\[\s*(.*?)\s*\][ \t]*\n/\n/s) {
            # $result .= "<summary>" . $self->_RunSpanGamut($1) . "</summary>\n";
        }

        # Now, divide table into header, alignment, and body

        # First, add leading \n in case there is no header

        $table = "\n" . $table;

        # Need to be greedy

        $table =~ s/\n($table_divider)\n(($table_rows)+)//s;

        my $alignment_string = $1;
        my $body = $2;

        # Process column alignment
        while ($alignment_string =~ /\|?\s*(.+?)\s*(\||\Z)/gs) {
            my $cell = $self->_RunSpanGamut($1);
            if ($cell =~ /\:$/) {
                if ($cell =~ /^\:/) {
                    $result .= qq[<col align="center"$self->{empty_element_suffix}\n];
                    push(@alignments,"center");
                }
                else {
                    $result .= qq[<col align="right"$self->{empty_element_suffix}\n];
                    push(@alignments,"right");
                }
            }
            else {
                if ($cell =~ /^\:/) {
                    $result .= qq[<col align="left"$self->{empty_element_suffix}\n];
                    push(@alignments,"left");
                }
                else {
                    if (($cell =~ /^\./) || ($cell =~ /\.$/)) {
                        $result .= qq[<col align="char"$self->{empty_element_suffix}\n];
                        push(@alignments,"char");
                    }
                    else {
                        $result .= "<col$self->{empty_element_suffix}\n";
                        push(@alignments,"");
                    }
                }
            }
        }

        # Process headers
        $table =~ s/^\n+//s;

        $result .= "<thead>\n";

        # Strip blank lines
        $table =~ s/\n[ \t]*\n/\n/g;

        foreach my $line (split(/\n/, $table)) {
            # process each line (row) in table
            $result .= "<tr>\n";
            my $count=0;
            while ($line =~ /\|?\s*([^\|]+?)\s*(\|+|\Z)/gs) {
                # process contents of each cell
                my $cell = $self->_RunSpanGamut($1);
                my $ending = $2;
                my $colspan = "";
                if ($ending =~ s/^\s*(\|{2,})\s*$/$1/) {
                    $colspan = " colspan=\"" . length($ending) . "\"";
                }
                $result .= "\t<th$colspan>$cell</th>\n";
                if ( $count == 0) {
                    if ($cell =~ /^\s*$/) {
                        $use_row_header = 1;
                    }
                    else {
                        $use_row_header = 0;
                    }
                }
                $count++;
            }
            $result .= "</tr>\n";
        }

        # Process body

        $result .= "</thead>\n<tbody>\n";

        foreach my $line (split(/\n/, $body)) {
            # process each line (row) in table
            if ($line =~ /^\s*$/) {
                $result .= "</tbody>\n\n<tbody>\n";
                next;
            }
            $result .= "<tr>\n";
            my $count=0;
            while ($line =~ /\|?\s*([^\|]+?)\s*(\|+|\Z)/gs) {
                # process contents of each cell
                no warnings 'uninitialized';
                my $cell = $self->_RunSpanGamut($1);
                my $ending = $2;
                my $colspan = "";
                my $cell_type = "td";
                if ($count == 0 && $use_row_header == 1) {
                    $cell_type = "th";
                }
                if ($ending =~ s/^\s*(\|{2,})\s*$/$1/) {
                    $colspan = " colspan=\"" . length($ending) . "\"";
                }
                if ($alignments[$count] !~ /^\s*$/) {
                    $result .= "\t<$cell_type$colspan align=\"$alignments[$count]\">$cell</$cell_type>\n";
                }
                else {
                    $result .= "\t<$cell_type$colspan>$cell</$cell_type>\n";
                }
                $count++;
            }
            $result .= "</tr>\n";
        }

        $result .= "</tbody>\n</table>\n";
        $result
    }egmx;

    my $table_body = qr{
        (                               # wrap whole match in $2

            (.*?\|.*?)\n                    # wrap headers in $3

            [ ]{0,$less_than_tab}
            ($table_divider)    # alignment in $4

            (                           # wrap cells in $5
                $table_rows
            )
        )
    }mx;

    return $text;
}

sub _DoAttributes {
    my ($self, $id) = @_;
    my $result = "";

    if (defined $self->{_attributes}{$id}) {
        while ($self->{_attributes}{$id} =~ s/(\S+)="(.*?)"//) {
            $result .= qq{ $1="$2"};
        }
        while ($self->{_attributes}{$id} =~ /(\S+)=(\S+)/g) {
            $result .= qq{ $1="$2"};
        }
    }

    return $result;
}

sub _StripMarkdownReferences {
    my ($self, $text) = @_;
    my $less_than_tab = $self->{tab_width} - 1;

    while ($text =~ s{
        \n\[\#(.+?)\]:[ \t]*    # id = $1
        \n?
        (.*?)\n{1,2}            # end at new paragraph
        ((?=\n[ ]{0,$less_than_tab}\S)|\Z)  # Lookahead for non-space at line-start, or end of doc
    }
    {\n}sx)
    {
        my $id = $1;
        my $reference = "$2\n";

        $reference =~ s/^[ ]{0,$self->{tab_width}}//gm;

        $reference = $self->_RunBlockGamut($reference, {wrap_in_p_tags => 0});

        $self->{_references}{$id} = $reference;
    }

    return $text;
}

sub _DoMarkdownCitations {
    my ($self, $text) = @_;

    $text =~ s{
        \[([^\[]*?)\]       # citation text = $1
        [ ]?            # one optional space
        (?:\n[ ]*)?     # one optional newline followed by spaces
        \[\#(.*?)\]     # id = $2
    }{
        my $result;
        my $anchor_text = $1;
        my $id = $2;
        my $count;

        if (defined $self->{_references}{$id} ) {
            my $citation_counter=0;

            # See if citation has been used before
            foreach my $old_id (@{ $self->{_used_references} }) {
                $citation_counter++;
                $count = $citation_counter if ($old_id eq $id);
            }

            if (! defined $count) {
                $count = ++$self->{_citation_counter};
                push (@{ $self->{_used_references} }, $id);
            }

            $result = qq[<span class="markdowncitation"> (<a href="#$id">$count</a>];

            if ($anchor_text ne "") {
                $result .= qq[, <span class="locator">$anchor_text</span>];
            }

            $result .= ")</span>";
        }
        else {
            # No reference exists
            $result = qq[<span class="externalcitation"> (<a id="$id">$id</a>];

            if ($anchor_text ne "") {
                $result .= qq[, <span class="locator">$anchor_text</span>];
            }

            $result .= ")</span>";
        }

        if ($self->_Header2Label($anchor_text) eq "notcited"){
            $result = qq[<span class="notcited" id="$id"/>];
        }
        $result;
    }xsge;

    return $text;
}

sub _PrintMarkdownBibliography {
    my ($self) = @_;
    my $citation_counter = 0;
    my $result;

    foreach my $id (@{ $self->{_used_references} }) {
        $citation_counter++;
        $result .= qq|<div id="$id"><p>[$citation_counter] <span class="item">$self->{_references}{$id}</span></p></div>\n\n|;
    }
    $result .= "</div>";

    if ($citation_counter > 0) {
        $result = qq[\n\n<div class="bibliography">\n<hr$self->{empty_element_suffix}\n<p>$self->{bibliography_title}</p>\n\n] . $result;
    }
    else {
        $result = "";
    }

    return $result;
}

1;

=back

=head1 BUGS

Open an issue in the GitHub repo:

	https://github.com/briandfoy/text-multimarkdown/issues

Please include with your report: (1) the example input; (2) the output
you expected; (3) the output Markdown actually produced.

=head1 VERSION HISTORY

See the Changes file for detailed release notes for this version.

=head1 AUTHOR

=over 4

=item * John Gruber http://daringfireball.net/

=item * PHP port and other contributions by Michel Fortin http://michelf.com/

=item * MultiMarkdown changes by Fletcher Penney http://fletcher.freeshell.org/

=item * CPAN Module Text::MultiMarkdown (based on Text::Markdown by Sebastian Riedel) originally by Darren Kulp (http://kulp.ch/)

=item * This module was maintained by: Tomas Doran http://www.bobtfish.net/

=item * This module is currently maintained by brian d foy

=back

=head1 THIS DISTRIBUTION

Please note that this distribution is a fork of Fletcher Penny's MultiMarkdown project,
and it I<is not> in any way blessed by him.

Whilst this code aims to be compatible with the original MultiMarkdown (and incorporates
and passes the MultiMarkdown test suite) whilst fixing a number of bugs in the original -
there may be differences between the behaviour of this module and MultiMarkdown. If you find
any differences where you believe Text::MultiMarkdown behaves contrary to the MultiMarkdown spec,
please report them as bugs.

=head1 SOURCE CODE

You can find the source code repository for L<Text::Markdown> and L<Text::MultiMarkdown>
on GitHub at <http://github.com/bobtfish/text-markdown>.

=head1 COPYRIGHT AND LICENSE

Original Code Copyright (c) 2003-2004 John Gruber
<http://daringfireball.net/>
All rights reserved.

MultiMarkdown changes Copyright (c) 2005-2006 Fletcher T. Penney
<http://fletcher.freeshell.org/>
All rights reserved.

Text::MultiMarkdown changes Copyright (c) 2006-2009 Darren Kulp
<http://kulp.ch> and Tomas Doran <http://www.bobtfish.net>

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

* Redistributions of source code must retain the above copyright notice,
  this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright
  notice, this list of conditions and the following disclaimer in the
  documentation and/or other materials provided with the distribution.

* Neither the name "Markdown" nor the names of its contributors may
  be used to endorse or promote products derived from this software
  without specific prior written permission.

This software is provided by the copyright holders and contributors "as
is" and any express or implied warranties, including, but not limited
to, the implied warranties of merchantability and fitness for a
particular purpose are disclaimed. In no event shall the copyright owner
or contributors be liable for any direct, indirect, incidental, special,
exemplary, or consequential damages (including, but not limited to,
procurement of substitute goods or services; loss of use, data, or
profits; or business interruption) however caused and on any theory of
liability, whether in contract, strict liability, or tort (including
negligence or otherwise) arising in any way out of the use of this
software, even if advised of the possibility of such damage.

=cut
