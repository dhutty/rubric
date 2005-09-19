package Rubric::Entry;

use strict;
use warnings;

=head1 NAME

Rubric::Entry - a single entry made by a user

=head1 VERSION

 $Id$

=head1 DESCRIPTION

This class provides an interface to Rubric entries.  It inherits from
Rubric::DBI, which is a Class::DBI class.

=cut

use base qw(Rubric::DBI);
use Encode qw(_utf8_on);
use Time::Piece;

__PACKAGE__->table('entries');

=head1 COLUMNS

 id          - a unique identifier
 link        - the link to which the entry refers
 user        - the user who made the entry
 title       - the title of the link's destination
 description - a short description of the entry
 body        - a long body of text for the entry
 created     - the time when the entry was first created
 modified    - the time when the entry was last modified

=cut

__PACKAGE__->columns(
	All => qw(id link user title description body created modified)
);

=head1 RELATIONSHIPS

=head2 link

The link attribute returns a Rubric::Link.

=cut

__PACKAGE__->has_a(link => 'Rubric::Link');

=head2 uri

The uri attribute returns the URI of the entry's link.

=cut

sub uri { my ($self) = @_; return unless $self->link; $self->link->uri; }

=head2 user

The user attribute returns a Rubric::User.

=cut

__PACKAGE__->has_a(user => 'Rubric::User');

=head2 tags

Every entry has_many tags that describe it.  The C<tags> method will return the
tags, and the C<entrytags> method will return the Rubric::EntryTag objects that
represent them.

=cut

__PACKAGE__->has_many(entrytags => 'Rubric::EntryTag' );
__PACKAGE__->has_many(tags => [ 'Rubric::EntryTag' => 'tag' ]);

=head3 recent_tags_counted

This method returns a reference to an array of arrayrefs, each a (tag, count)
pair for tags used on the week's 50 most recent entries.

=cut

__PACKAGE__->set_sql(recent_tags_counted => <<'');
SELECT tag, COUNT(*) as count
FROM   entrytags
WHERE entry IN (SELECT id FROM entries WHERE created > ? LIMIT 100)
  AND tag NOT LIKE '@%%'
GROUP BY tag
ORDER BY count DESC
LIMIT 50

sub recent_tags_counted {
	my ($class) = @_;
	my $sth = $class->sql_recent_tags_counted;
	$sth->execute(time - (86400 * 7));
	my $result = $sth->fetchall_arrayref;
	return $result;
}

=head1 INFLATIONS

=head2 created

=head2 modified

The created and modified columns are stored as seconds since epoch, but
inflated to Time::Piece objects.

=cut

__PACKAGE__->has_a(
	$_ => 'Time::Piece',
	deflate => 'epoch',
	inflate => Rubric::Config->display_localtime ? sub { localtime($_[0]) }
	                                             : sub { gmtime($_[0]) }
) for qw(created modified);

__PACKAGE__->add_trigger(before_create => \&_default_title);

__PACKAGE__->add_trigger(before_create => \&_create_times);
__PACKAGE__->add_trigger(before_update => \&_update_times);

sub _default_title {
	my $self = shift;
	$self->title('(default)') unless $self->{title}
}

sub _create_times {
	my $self = shift;
	$self->created(scalar gmtime) unless defined $self->{created};
	$self->modified(scalar gmtime) unless defined $self->{modified};
}

sub _update_times {
	my $self = shift;
	$self->modified(scalar gmtime);
}

=head1 METHODS

=head2 query(\%arg)

The arguments to C<query> provide a set of abstract constraints for the query.
These are sent to Rubric::Entry::Query, which builds an SQL query and returns
the result of running it.  (Either a list or an Iterator is returned.)

(The built-in Class::DBI search method can't handle this kind of search.)

 user   - entries for this User
 tags   - entries with these tags (arrayref)
 link   - entries for this Link
 urimd5 - entries for the Link with this md5 sum
 has_body    - whether entries must have bodies (T, F, or undef)
 has_link    - whether entries must have a link (T, F, or undef)
 (time spec) - {created,modified}_{before,after,on}
               limits entries by time; given as a complete or partial
               time and date string in the form "YYYY-MM-DD HH:MM"

=cut

sub query {
	my $self = shift;
	require Rubric::Entry::Query;
	Rubric::Entry::Query->query(@_);
}

=head2 set_new_tags(\%tags)

This method replaces all entry's current tags with the new set of tags.

=cut

sub set_new_tags {
	my ($self, $tags) = @_;
	$self->entrytags->delete_all;
	$self->update;

  while (my ($tag, $value) = each %$tags) {
    $self->add_to_tags({ tag => $tag, tag_value => $value });
  }
}

=head2 tags_from_string($taglist)

This (class) method takes a string of tags, delimited by whitespace, and
returns an array of the tags, dropping invalid tags.

Valid tags (shouldn't this be documented somewhere else instead?) may contain
letters, numbers, underscores, colons, dots, and asterisks.  Hyphens me be
used, but not as the first character.

=cut

sub tags_from_string {
	my ($class, $tagstring) = @_;
	my %seen;

	_utf8_on($tagstring);

	my %tags = $tagstring ? map { (index($_, ':') > 0) ? split(/:/, $_, 2) : ($_ => undef) }
	                        split /(?:\+|\s)+/, $tagstring
	                      : ();

	die "invalid characters in tagstring" 
		if grep { defined $_ and $_ !~ /\A[@\w\d:.*][-\w\d:.*]*\Z/ } keys %tags;

	die "invalid characters in tagstring" 
		if grep { defined $_ and $_ !~ /\A[-\w\d:.*]*\Z/ } values %tags;

	return \%tags;
}

## return retrieve_all'd objects in recent-to-older order

__PACKAGE__->set_sql(RetrieveAll => <<'');
SELECT __ESSENTIAL__
FROM   __TABLE__
ORDER BY created DESC

=head1 TODO

=head1 AUTHOR

Ricardo SIGNES, C<< <rjbs@cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-rubric@rt.cpan.org>, or
through the web interface at L<http://rt.cpan.org>. I will be notified, and
then you'll automatically be notified of progress on your bug as I make
changes.

=head1 COPYRIGHT

Copyright 2004 Ricardo SIGNES.  This program is free software;  you can
redistribute it and/or modify it under the same terms as Perl itself.

=cut

1;