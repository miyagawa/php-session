package PHP::Session::Serializer::PHP;

use strict;
use Text::Balanced qw(extract_bracketed);

use vars qw($VERSION);
$VERSION = 0.16;

sub _croak { require Carp; Carp::croak(@_) }

sub new {
    my $class = shift;
    bless { _data => {} }, $class;
}

my $var_re = '(\w+)\|';
#my $str_re = 's:\d+:"(.*?)";';
my $str_re = 's:(\d+):';
my $int_re = 'i:(-?\d+);';
my $dbl_re = 'd:(-?\d+(?:\.\d+)?);';
my $arr_re = 'a:(\d+):';
#my $obj_re = 'O:\d+:"(.*?)":\d+:';
my $obj_re = 'O:(\d+):';
my $nul_re = '(N);';
my $bool_re = 'b:([01]);';

use constant VARNAME   => 0;
use constant STRLEN    => 1;
use constant INTEGER   => 2;
use constant DOUBLE    => 3;
use constant ARRAY     => 4;
use constant CLASSLEN  => 5;
use constant NULL      => 6;
use constant BOOLEAN   => 7;

sub decode {
    my($self, $data) = @_;
    while ($data and $data =~ s/^(!?)$var_re(?:$str_re|$int_re|$dbl_re|$arr_re|$obj_re|$nul_re|$bool_re)?//s) {
	my $UNDEF = $1;
	my @match = ($2, $3, $4, $5, $6, $7, $8, $9);

	# literal: integer, double, boolean
	my @literal = grep defined, @match[INTEGER, DOUBLE, BOOLEAN];
	@literal and $self->{_data}->{$match[VARNAME]} = $literal[0], next;

	# string
	if (my $len = $match[STRLEN]) {
	    $data =~ s/^"(.{$len})";// or die "weird data: $data";
	    $self->{_data}->{$match[VARNAME]} = $1;
	    next;
	}

	# undef or NULL
	if ($UNDEF eq '!' or defined $match[NULL]) {
	    $self->{_data}->{$match[VARNAME]} = undef;
	    next;
	}

	# nested: array, object
	my $class_name;
	if (my $len = $match[CLASSLEN]) {
	    $data =~ s/^"(.{$len})":\d+:// or die "weird data: $data";
	    $class_name = $1;
	}

	my $bracket = extract_bracketed($data, '{}');
	my %data    = $self->do_decode($bracket);
	if (defined $match[ARRAY]) {
	    $self->{_data}->{$match[VARNAME]} = \%data;
	}
	elsif (defined $class_name) {
	    $self->{_data}->{$match[VARNAME]} = bless {
		_class => $class_name,
		%data,
	    }, 'PHP::Session::Object';
	}
    }
    return $self->{_data};
}

sub do_decode {
    my($self, $data) = @_;
    $data =~ s/^{(.*)}$/$1/s;
    my @data;
    while ($data and $data =~ s/^($str_re|$int_re|$dbl_re|$arr_re|$obj_re|$nul_re|$bool_re)//) {
	my @match = ($1, $2, $3, $4, $5, $6, $7, $8);

	# literal: integer, double. boolean
	my @literal = grep defined, @match[INTEGER, DOUBLE, BOOLEAN];
	@literal and push @data, $literal[0] and next;

	# string
	if (my $len = $match[STRLEN]) {
	    $data =~ s/^"(.{$len})";// or die "weird data: $data";
	    push @data, $1;
	    next;
	}

	# NULL
	if (defined $match[NULL]) {
	    push @data, undef;
	    next;
	}

	# nexted: array, object
	my $class_name;
	if (my $len = $match[CLASSLEN]) {
	    $data =~ s/^"(.{$len})":\d+:// or die "weird data: $data";
	    $class_name = $1;
	}

	my $bracket = extract_bracketed($data, '{}');
	my %data    = $self->do_decode($bracket);
	if (defined $match[ARRAY]) {
	    push @data, \%data;
	}
	elsif (defined $class_name) {
	    push @data, bless {
		_class => $class_name,
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
	if (defined $data->{$key}) {
	    $body .= "$key|" . $self->do_encode($data->{$key});
	} else {
	    $body .= "!$key|";
    	}
    }
    return $body;
}

sub do_encode {
    my($self, $value) = @_;
    if (! defined $value) {
	return $self->encode_null($value);
    }
    elsif (! ref $value) {
#	if ($value =~ /^-?\d+$/) {
	if (is_int($value)) {
	    return $self->encode_int($value);
	}
#	elsif ($value =~ /^-?\d+(?:\.\d+)?$/) {
	elsif (is_float($value)) {
	    return $self->encode_double($value);
	}
	else {
	    return $self->encode_string($value);
	}
    }
    elsif (ref $value eq 'HASH') {
	return $self->encode_array($value);
    }
    elsif (ref $value eq 'ARRAY') {
	return $self->encode_array($value);
    }
    elsif (ref $value eq 'PHP::Session::Object') {
	return $self->encode_object($value);
    }
    else {
	_croak("Can't encode ", ref($value));
    }
}

sub encode_null {
    my($self, $value) = @_;
    return 'N;';
}

sub encode_int {
    my($self, $value) = @_;
    return sprintf 'i:%d;', $value;
}

sub encode_double {
    my($self, $value) = @_;
    return sprintf "d:%s;", $value; # XXX hack
}

sub encode_string {
    my($self, $value) = @_;
    return sprintf 's:%d:"%s";', length($value), $value;
}

sub encode_array {
    my($self, $value) = @_;
    my %array = ref $value eq 'HASH' ? %$value : map { $_ => $value->[$_] } 0..$#{$value};
    return sprintf 'a:%d:{%s}', scalar(keys %array), join('', map $self->do_encode($_), %array);
}

sub encode_object {
    my($self, $value) = @_;
    my %impl = %$value;
    my $class = delete $impl{_class};
    return sprintf 'O:%d:"%s":%d:{%s}', length($class), $class, 2 * (keys %impl),
	join('', map $self->do_encode($_), %impl);
}

sub is_int {
    local $_ = shift;
    /^-?[0-9]\d{0,8}$/;
}

sub is_float {
    local $_ = shift;
    /^-?[0-9]\d{0,8}\.\d+$/;
}

1;
__END__

=head1 NAME

PHP::Session::Serializer::PHP - serialize / deserialize PHP session data

=head1 SYNOPSIS

  use PHP::Session::Serializer::PHP;

  $serializer = PHP::Session::Serializer::PHP->new;

  $enc     = $serializer->encode(\%data);
  $hashref = $serializer->decode($enc);

=head1 TODO

=over 4

=item *

clean up the code!

=item *

Add option to restore PHP object as is.

=back

=head1 AUTHOR

Tatsuhiko Miyagawa E<lt>miyagawa@bulknews.netE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<PHP::Session>

=cut

