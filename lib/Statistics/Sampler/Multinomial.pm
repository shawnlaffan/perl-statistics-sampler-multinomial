package Statistics::Sampler::Multinomial;

use 5.010;
use warnings;
use strict;

our $VERSION = '0.0_001';

use Carp;
use Ref::Util qw /is_arrayref/;
use List::Util qw /min sum/;
use List::MoreUtils qw /first_index/;
use Scalar::Util qw /blessed/;
use POSIX qw /floor/;

sub new {
    my ($class, $args) = @_;
    
    my $prng = $args->{prng}
      // croak 'prng arg not passed';  #  should make a default which calls the perl PRNG 

    croak 'prng arg is not an object' if not blessed $prng;
    croak 'prng arg does not have rand() method' if not $prng->can('rand');

    my $self = bless {prng => $prng}, $class;
    return $self;
}

sub initialise {
    my ($self, %args) = @_;

    
    my $probs = $args{data} || $args{prob_array};
    my $probs_sum_to_one = $args{data_sum_to_one} // $args{probs_sum_to_one};

    croak "data arg is not an array ref"
      if !is_arrayref($probs);

    my $have_neg = first_index {$_ < 0} @$probs;
    croak "negative values passed in data array"
      if $have_neg >= 0;

    if (!$probs_sum_to_one) {  #  caller has not promised they sum to 1
        my $sum = sum (@$probs);
        if ($sum != 1) {
            my @scaled_probs = map {$_ / $sum} @$probs;
            $probs = \@scaled_probs;
        }
    }
    $self->{probs} = $probs;

    #  algorithm and comments stolen/adapted from
    #  https://hips.seas.harvard.edu/blog/2013/03/03/the-alias-method-efficient-sampling-with-many-discrete-outcomes/

    my (@smaller, @larger);
    my @J = (0) x scalar @$probs;
    my @q = (0) x scalar @$probs;
    my $kk = -1;
    my $K = scalar @$probs;

    foreach my $prob (@$probs){
        $kk++;
        $q[$kk] = $K * $prob;
        if ($q[$kk] < 1.0) {
            push @smaller, $kk
        }
        else {
            push @larger, $kk;
        }
    }
    
    # Loop though and create little binary mixtures that
    # appropriately allocate the larger outcomes over the
    # overall uniform mixture.
    while (scalar @smaller && scalar @larger) {
        my $small = pop @smaller;
        my $large = pop @larger;
 
        $J[$small] = $large;
        $q[$large] = ($q[$large] + $q[$small]) - 1;
 
        if ($q[$large] < 1.0) {
            push @smaller, $large;
        }
        else {
            push @larger, $large;
        }
    }
    # handle numeric stability issues
    # courtesy http://www.keithschwarz.com/darts-dice-coins/
    while (scalar @larger) {
        my $g = shift @larger;
        $q[$g] = 1;
    }
    while (scalar @smaller) {
        my $l = shift @smaller;
        $q[$l] = 1;
    }

    #  need better names for these,
    $self->{J} = \@J;
    $self->{q} = \@q;

    return if !defined wantarray;

    #  should not expose these to the caller
    my %results = (J => \@J, q => \@q);
    return wantarray ? %results : \%results;
}

sub get_class_count {
    my $self = shift;
    my $aref = $self->{probs};
    return scalar @$aref;
}

sub draw {
    my ($self, $args) = @_;

    my $prng = $self->{prng};

    my $q  = $self->{q}
      // croak 'it appears setup has not been run yet';
    my $J  = $self->{J};
    my $K  = scalar @$J;
    my $kk = floor ($prng->rand * $K);
 
    # Draw from the binary mixture, either keeping the
    # small one, or choosing the associated larger one.
    return $prng->rand < $q->[$kk] ? $kk : $J->[$kk];
}

sub draw_n_samples {
    my ($self, $n) = @_;
    
    my $prng = $self->{prng};

    my $q  = $self->{q}
      // croak 'it appears setup has not been run yet';
    my $J  = $self->{J};
    my $K  = scalar @$J;
    
    my @draws;
    foreach my $i (1..$n) {
        my $kk = floor ($prng->rand * $K);
        # Draw from the binary mixture, either keeping the
        # small one, or choosing the associated larger one.
        push @draws, $prng->rand < $q->[$kk] ? $kk : $J->[$kk];
    }
 
    return wantarray ? @draws : \@draws;
}

1;
__END__

=head1 NAME

Statistics::Sampler::Multinomial - Generate multinomial samples given a distribution


=head1 VERSION

This document describes Statistics::Sampler::Multinomial version 0.0_001


=head1 SYNOPSIS

    use Statistics::Sampler::Multinomial;

=for author to fill in:
    Brief code example(s) here showing commonest usage(s).
    This section will be as far as many users bother reading
    so make it as educational and exeplary as possible.
  
  
=head1 DESCRIPTION

=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.


=head1 METHODS

=over 4

=item my $object = Statistics::Sampler::Multinomial->new()

=item my $object = Statistics::Sampler::Multinomial->new (prng => $prng)

Creates a new object, optionally passing the PRNG object to be used.
If no PRNG object is passed then it defaults to XXX.

=item $object->initialise (data => [1, 4, 5])

=item $object->initialise (data => [0.1, 0.4, 0.5], data_sum_to_one => 1)

Initialise the alias tables given an array of proportions
for a set of K classes (each class corresponds with an array entry).

By default it will standardise the data to sum to one
but callers can skip this step by promising that the
data already sum to one.  No checks of the validity of
such promises are made, so expect failures for lying.

=item $object->draw

Draw one sample from the distribution.
Returns the chosen class number.

Croaks if called before initialise has been called.

=item $object->draw_n_samples ($n)

Returns an array of $n samples.  Each array entry
is the value of a randomly selected class number.
e.g. for $n=5 and the K=3 example from above,
one could get (0,2,1,0,0).

Returns an array ref in scalar context.

Croaks if called before initialise has been called.

=item $object->get_class_count

Returns the number of classes in the sample,
or zero if initialise has not yet been run.

=back




=head1 BUGS AND LIMITATIONS

Please report any bugs or feature requests to
C<bug-statistics-sampler-multinomial@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 AUTHOR

Shawn Laffan  C<< <shawnlaffan@gmail.com> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2016, Shawn Laffan C<< <shawnlaffan@gmail.com> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
