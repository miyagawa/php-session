package PHP::Session::Serializer::PHP;

use strict;
use Text::Balanced qw(extract_bracketed);

use vars qw($VERSION);
$VERSION = 0.04;

sub _croak { require Carp; Carp::croak(@_) }

sub new {
    my $class = shift;
    bless { _data => {} }, $class;
}

my $var_re = '(\w+)\|';
my $str_re = 's:\d+:"(.*?)"\;';
my $int_re = 'i:(\d+);';
my $dig_re = 'd:([\-\d\.]+);';
my $arr_re = 'a:(\d+):';
my $obj_re = 'O:\d+:"(.*?)":\d+:';
my $nul_re = '(N);';

use constant VARNAME   => 0;
use constant STRING    => 1;
use constant INTEGER   => 2;
use constant DIGIT     => 3;
use constant ARRAY     => 4;
use constant CLASSNAME => 5;
use constant NULL      => 6;

sub decode {
    my($self, $data) = @_;
    while ($data =~ s/^$var_re(?:$str_re|$int_re|$dig_re|$arr_re|$obj_re|$nul_re)//) {
	my @match = ($1, $2, $3, $4, $5, $6, $7);
	my @literal = grep defined, @match[STRING, INTEGER, DIGIT];
	@literal and $self->{_data}->{$match[VARNAME]} = $literal[0], next;

	if (defined $match[NULL]) {
	    $self->{_data}->{$match[VARNAME]} = undef;
	    next;
	}

	my $bracket = extract_bracketed($data, '{}');
	my %data    = $self->do_decode($bracket);
	if (defined $match[ARRAY]) {
	    $self->{_data}->{$match[VARNAME]} = \%data;
	}
	elsif (defined $match[CLASSNAME]) {
	    $self->{_data}->{$match[VARNAME]} = bless {
		_class => $match[CLASSNAME],
		%data,
	    }, 'PHP::Session::Object';
	}
    }
    return $self->{_data};
}

sub do_decode {
    my($self, $data) = @_;
    $data =~ s/^{(.*)}$/$1/;
    my @data;
    while ($data =~ s/^($str_re|$int_re|$dig_re|$arr_re|$obj_re)//) {
	my @match = ($1, $2, $3, $4, $5, $6, $7);
	my @literal = grep defined, @match[STRING, INTEGER, DIGIT];
	@literal and push @data, $literal[0] and next;

	if (defined $match[NULL]) {
	    push @data, undef;
	    next;
	}

	my $bracket = extract_bracketed($data, '{}');
	my %data    = $self->do_decode($bracket);
	if (defined $match[ARRAY]) {
	    push @data, \%data;
	}
	elsif (defined $match[CLASSNAME]) {
	    push @data, bless {
		_class => $match[CLASSNAME],
		%data,
	    }, 'PHP::Session::Object';
	}
    }
    return @data;
}

sub encode {
    my($self, $data) = @_;
    my $body;
    for my $key (keys %$data) {
	$body .= "$key|" . $self->do_encode($data->{$key});
    }
    return $body;
}

sub do_encode {
    my($self, $value) = @_;
    if (! defined $value) {
	return $self->encode_undef($value);
    }
    elsif (! ref $value) {
	if ($value =~ /^\d+$/) {
	    return $self->encode_int($value);
	}
	elsif ($value =~ /^[\d\-\.]+$/) {
	    return $self->encode_digit($value);
	}
	else {
	    return $self->encode_string($value);
	}
    }
    elsif (ref $value eq 'HASH') {
	return $self->encode_hash($value);
    }
    elsif (ref $value eq 'PHP::Session::Object') {
	return $self->encode_object($value);
    }
    else {
	_croak("Can't encode ", ref($value));
    }
}

sub encode_undef {
    my($self, $value) = @_;
    return 'N;';
}

sub encode_int {
    my($self, $value) = @_;
    return sprintf 'i:%d;', $value;
}

sub encode_digit {
    my($self, $value) = @_;
    return sprintf "d:%d;", $value;
}

sub encode_string {
    my($self, $value) = @_;
    return sprintf 's:%d:"%s";', length($value), $value;
}

sub encode_hash {
    my($self, $value) = @_;
    return sprintf 'a:%d:{%s}', 2 * (keys %$value), join('', map $self->do_encode($_), %$value);
}

sub encode_object {
    my($self, $value) = @_;
    my %impl = %$value;
    my $class = delete $impl{_class};
    return sprintf 'O:%d:"%s":%d:{%s}', length($class), $class, 2 * (keys %impl),
	join('', map $self->do_encode($_), %impl);
}

1;
__END__

=head1 NAME

PHP::Session::Serializer::PHP - serialize / deserialize PHP session data

=head1 SYNOPSIS

B<DO NOT USE THIS MODULE DIRECTLY>.

=head1 TODO

=over 4

=item *

clean up the code!

=back

=head1 AUTHOR

Tatsuhiko Miyagawa E<lt>miyagawa@bulknews.netE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<PHP::Session>

=cut

