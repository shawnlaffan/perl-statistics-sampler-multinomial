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

sub new {
    my ($class, %args) = @_;
    
    my $prng = $args{prng};

    #  Math::Random::MT::Auto has boolean op overloading
    #  so make sure we don't trigger it or our tests fail
    #  (and we waste a random number, but that's less of an issue)
    if (defined $prng) {
        croak 'prng arg is not an object'
          if not blessed $prng;
        croak 'prng arg does not have rand() method'
          if not $prng->can('rand');
    }

    $prng //= Statistics::Sampler::Multinomial::DefaultPRNG->new;

    my $self = bless {prng => $prng}, $class;

    return $self;
}

sub _initialise {
    my ($self, %args) = @_;

    my $probs = $self->{data};

    #  caller has not promised they sum to 1
    if (!$self->{data_sum_to_one}) {  
        my $sum = sum (@$probs);
        if ($sum != 1) {
            my @scaled_probs = map {$_ / $sum} @$probs;
            $probs = \@scaled_probs;
        }
    }

    return;
}

sub get_class_count {
    my $self = shift;
    my $aref = $self->{data};
    return scalar @$aref;
}

sub draw {
    my ($self, $args) = @_;

    #  inefficient, but why would one want a single draw?
    #  here for compatibility with SSM::AliasMethod
    return $self->draw_n_samples (1);
}

sub draw_n_samples {
    my ($self, $n) = @_;

    my $prng = $self->{prng};

    my $data  = $self->{data}
      // croak 'it appears setup has not been run yet';
    my $K    = scalar @$data;
    my $norm = $self->{sum} // do {$self->_initialise; $self->{sum}};

    my @draws;
    my ($sum_p, $sum_n) = (0, 0);

    foreach my $kk (0..($K-1)) {
        if (!$data->[$kk]) {
            $draws[$kk] = 0;
            next;
        }

        my $res = $prng->binomial (
            min (1, $data->[$kk] / ($norm - $sum_p)),
            ($n - $sum_n),
        );
        $draws[$kk] = $res;
        $sum_p += $data->[$kk];
        $sum_n += $res;
    }

    return \@draws;
}

##  Cuckoo package to act as a method wrapper
##  to use the perl PRNG stream by default. 
#package Statistics::Sampler::Multinomial::DefaultPRNG {
#    sub new {
#        return bless {}, __PACKAGE__;
#    }
#    sub rand {
#        rand();
#    }
#}

1;
__END__

=head1 NAME

Statistics::Sampler::Multinomial - Generate multinomial samples using Vose's alias method


=head1 VERSION

This document describes Statistics::Sampler::Multinomial version 0.0_001


=head1 SYNOPSIS

    use Statistics::Sampler::Multinomial;

    my $object = Statistics::Sampler::Multinomial->new();
    $object->initialise (data => [0.1, 0.3, 0.2, 0.4]);
    $object->draw;
    #  returns a number between 0..3
    my $samples = $object->draw_n_samples(5)
    #  returns an array ref that might look something like
    #  [3,3,0,2,0]
    
    # to specify your own PRNG object, in this case the Mersenne Twister
    my $mrma = Math::Random::MT::Auto->new;
    my $object = Statistics::Sampler::Multinomial->new(prng => $mrma);


=head1 DESCRIPTION

Implements multinomial sampling using Vose's version of the alias method.

The setup time for the alias method is longer than for other methods,
and the memory requirements are larger since it maintains two lists in memory,
but this is amortised when 
when generating repeated samples because only two random numbers are
needed for each draw, as compared to up to O(log n) for other methods.
This has a pay off when, for example calculating 
bootstrap confidence intervals for a set of classes.
(This statement could do with some more thorough testing).

For more details and background, see L<http://www.keithschwarz.com/darts-dice-coins>.


=head1 METHODS

=over 4

=item my $object = Statistics::Sampler::Multinomial->new()

=item my $object = Statistics::Sampler::Multinomial->new (prng => $prng)

Creates a new object, optionally passing a PRNG object to be used.
If no PRNG object is passed then it defaults to an internal object
that uses the perl PRNG stream.

Passing your own PRNG mean you have control over the random number
stream used, and can use it as part of a separate analysis.
The only requirement of such an object is that it has a rand()
method that returns a value in the interval [0,1)
(the same as Perl's rand() builtin).

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

Returns an array ref of $n samples.  Each array entry
is the value of a randomly selected class number.
e.g. for $n=3 and the K=5 example from above,
one could get (0,2,1,0,0).

Croaks if called before initialise has been called.

=item $object->get_class_count

Returns the number of classes in the sample,
or zero if initialise has not yet been run.

=back


=head1 BUGS AND LIMITATIONS

Please report any bugs or feature requests to
L<https://github.com/shawnlaffan/perl-statistics-sampler-multinomial/issues>.

=head1 SEE ALSO

Much of the code has been adapted from a python implementation at
L<https://hips.seas.harvard.edu/blog/2013/03/03/the-alias-method-efficient-sampling-with-many-discrete-outcomes>.

These packages also have multinomial samplers but do not use the alias method,
and you cannot supply your own PRNG:
L<Math::Random>, L<Math::GSL::Randist>


=head1 AUTHOR

Shawn Laffan  C<< <shawnlaffan@gmail.com> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2016, Shawn Laffan C<< <shawnlaffan@gmail.com> >>.
All rights reserved.

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
