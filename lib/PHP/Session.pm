package PHP::Session;

use strict;
use vars qw($VERSION);
$VERSION = 0.04;

use vars qw(%SerialImpl);
%SerialImpl = (
    php => 'PHP::Session::Serializer::PHP',
);

use Fcntl qw(:flock);
use FileHandle;
use UNIVERSAL::require;

sub _croak { require Carp; Carp::croak(@_) }

sub new {
    my($class, $sid, $opt) = @_;
    my %default = (
	save_path         => '/tmp',
	serialize_handler => 'php',
    );
    $opt ||= {};
    my $self = bless {
	%default,
	%$opt,
	_sid  => $sid,
	_data => {},
    }, $class;
    $self->_validate_sid;
    $self->_parse_session;
    return $self;
}

# accessors, public methods

sub id { shift->{_sid} }

sub get {
    my($self, $key) = @_;
    return $self->{_data}->{$key};
}

sub set {
    my($self, $key, $value) = @_;
    $self->{_data}->{$key} = $value;
}

sub unregister {
    my($self, $key) = @_;
    delete $self->{_data}->{$key};
}

sub unset {
    my $self = shift;
    $self->{_data} = {};
}

sub is_registered {
    my($self, $key) = @_;
    return exists $self->{_data}->{$key};
}

sub decode {
    my($self, $data) = @_;
    $self->serializer->decode($data);
}

sub encode {
    my($self, $data) = @_;
    $self->serializer->encode($data);
}

sub save {
    my $self = shift;
    my $handle = FileHandle->new("> " . $self->_file_path)
	or _croak("can't write session file: $!");
    flock $handle, LOCK_EX;
    $handle->print($self->encode($self->{_data}));
    $handle->close;
}

sub destroy {
    my $self = shift;
    unlink $self->_file_path;
}

# private methods

sub _validate_sid {
    my $self = shift;
    my($id) = $self->id =~ /^([0-9a-zA-Z]*)$/; # untaint
    defined $id or _croak("Invalid session id: ", $self->id);
    $self->{_sid} = $id;
}

sub _parse_session {
    my $self = shift;
    my $cont = $self->_slurp_content;
    $self->{_data} = $self->decode($cont);
}

sub serializer {
    my $self = shift;
    my $impl = $SerialImpl{$self->{serialize_handler}};
    $impl->require;
    return $impl->new;
}

sub _file_path {
    my $self = shift;
    return $self->{save_path} . '/sess_' . $self->id;
}

sub _slurp_content {
    my $self = shift;
    my $handle = FileHandle->new($self->_file_path)
	or _croak("session file not found: $!");
    local $/ = undef;
    return scalar <$handle>;
}

1;
__END__

=head1 NAME

PHP::Session - read / write PHP session files

=head1 SYNOPSIS

  use PHP::Session;

  my $session = PHP::Session->new($id);

  # session id
  my $id = $session->id;

  # get/set session data
  my $foo = $session->get('foo');
  $session->set(bar => $bar);

  # remove session data
  $session->unregister('foo');

  # remove all session data
  $session->unset;

  # check if data is registered
  $session->is_registerd('bar');

  # save session data
  $session->save;

  # destroy session
  $session->destroy;

=head1 DESCRIPTION

PHP::Session provides a way to read / write PHP4 session files, with
which you can make your Perl application session shared with PHP4.

=head1 NOTES

=over 4

=item *

Array in PHP is hash in Perl.

=item *

Objects in PHP are deserialized as hash reference, blessed into
PHP::Session::Object (Null class).

=item *

Locking when save()ing data is acquired via exclusive flock, same as
PHP implementation.

=item *

Not tested so much, thus there may be a lot of bug in
(des|s)erialization code. If you find any, tell me via email.

=back

=head1 TODO

=over 4

=item *

WDDX support, using WDDX.pm

=item *

C<Apache::Session::PHP>

=back

=head1 AUTHOR

Tatsuhiko Miyagawa E<lt>miyagawa@bulknews.netE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<WDDX>, L<Apache::Session>, L<CGI::kSession>

=cut
