use 5.010;
use strict;
use warnings;

BEGIN {
    #  windows hackery to run in komodo without changing the perl and other things
    my $sep = ';';
    my @paths = ('\berrybrew\5.24.0_64_PDL\c\bin');
    $ENV{PATH} = join $sep, @paths, $ENV{PATH};
}

my $iters = 200;


use Benchmark qw {:all};

use List::Util qw /sum/;
use Statistics::Sampler::Multinomial;
use Math::Random qw/random_multinomial/;
use Math::GSL::Randist qw /gsl_ran_multinomial/;
use Math::GSL::RNG qw /gsl_rng_uniform $gsl_rng_mt19937/;

my $max = 1000;
my @data = map {int (rand() * $max)} (1 .. $max);

foreach my $K (10, 100, 1000) {
#foreach my $K (10, 100) {
    my @subset = @data[0..($K-1)];
    my $sum = sum @subset;
    my $scaled_data = [map {$_ / $sum} @subset];

    my $gsl_rng = Math::GSL::RNG->new($gsl_rng_mt19937);

    #  initialised version using default PRNG
    my $SSMi = Statistics::Sampler::Multinomial->new ();
    $SSMi->initialise (data => $scaled_data, data_sum_to_one => 1);

    #  uninitialised
    my $SSMu = Statistics::Sampler::Multinomial->new;

    my $N = $K;

    say "$N from $sum";
    
    #randist($gsl_rng, $N, $scaled_data);
    #SSMi_draw($SSMi, $N, $scaled_data);
    #math_random(undef, $N, $scaled_data);

    cmpthese (
        -2,
        {
            #  all get the same number of args
            randist => sub {randist($gsl_rng, $N, $scaled_data)},
            SSMi => sub {SSMi_draw($SSMi, $N, $scaled_data)},  
            #SSMu => sub {SSMu_draw($SSMu, $N, $scaled_data)},
            math_random => sub {math_random(undef, $N, $scaled_data)},
        }
    );
     
}



sub SSMi_draw {
    my ($object, $n) = @_;
    for (1..$iters) {
        my $res = $object->draw_n_samples($n);
    }
    my $x;
}

sub SSMu_draw {
    my ($object, $n, $data) = @_;
    $object->initialise(data => $data);
    for (1..$iters) {
        my $res = $object->draw_n_samples($n);
    }
}

sub randist {
    my ($object, $n, $data) = @_;
    
    for (1..$iters) {
        my $res = gsl_ran_multinomial ($object->raw, $data, $n);
    }
}

sub math_random {
    my ($object, $n, $data) = @_;
    for (1..$iters) {
        my @res = random_multinomial ($n, @$data);
    }
}

