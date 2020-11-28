use strict;
use warnings;
use 5.010;
use English qw /-no_match_vars/;

use Test::Most;


use rlib;
use Statistics::Sampler::Multinomial::Indexed;
use Math::Random::MT::Auto;
use List::Util qw /sum/;
use POSIX qw /logb/;


use Devel::Symdump;
my $functions_object = Devel::Symdump->rnew(__PACKAGE__); 
my @subs = grep {$_ =~ 'main::test_'} $functions_object->functions();

my @alias_keys = qw /J q/;

exit main( @ARGV );

sub main {
    my @args  = @_;

    if (@args) {
        for my $name (@args) {
            die "No test method test_$name\n"
                if not my $func = (__PACKAGE__->can( 'test_' . $name ) || __PACKAGE__->can( $name ));
            $func->();
        }
        done_testing;
        return 0;
    }


    foreach my $sub (sort @subs) {
        no strict 'refs';
        $sub->();
    }

    done_testing;
    return 0;
}


sub is_numeric_within_tolerance_or_exact_text {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my %args = @_;
    my ($got, $expected) = @args{qw /got expected/};

    if (looks_like_number ($expected) && looks_like_number ($got)) {
        my $result = ($args{tolerance} // 1e-10) > abs ($expected - $got);
        if (!$result) {
            #  sometimes we get diffs above the default due to floating point issues
            #  even when the two numbers are identical but only have 9dp
            $result = $expected eq $got;
        }
        ok ($result, $args{message});
    }
    else {
        is ($got, $expected, $args{message});
    }
}



sub test_draw {
    my $probs = [
        1, 5, 2, 6, 3, 8, 1, 4, 9
    ];
    
    my $prng1  = Math::Random::MT::Auto->new (seed => 2345);
    my $object = Statistics::Sampler::Multinomial::Indexed->new (
        prng => $prng1,
        data => $probs,
    );
    my $prng2  = Math::Random::MT::Auto->new (seed => 2345);
    my $object_non_indexed = Statistics::Sampler::Multinomial->new (
        prng => $prng2,
        data => $probs,
    );

    my $sum = sum @$probs;
    my $max_depth_idx = 1 + logb scalar @$probs;
    my $index = $object->{index};
    is_deeply ($index->[0], [$sum], 'top level of index');
    is_deeply ($index->[-1], $probs, 'bottom level of index');
    is ($#$index, $max_depth_idx, 'index depth');

    #  we should have the same result as the non-indexed draw1 method
    my $expected_draws = [map {$object_non_indexed->draw1()} (1..5)];
    my @draws = map {$object->draw()} (1..5);
    
    is_deeply \@draws, $expected_draws, 'got expected draws using draw method';
}


sub test_update_values {
    my $probs = [
        1, 5, 2, 6, 3, 5, 10
    ];
    
    my $prng1  = Math::Random::MT::Auto->new (seed => 2345);
    my $object = Statistics::Sampler::Multinomial::Indexed->new (
        prng => $prng1,
        data => $probs,
    );
    my $prng2  = Math::Random::MT::Auto->new (seed => 2345);
    my $object2 = Statistics::Sampler::Multinomial->new (
        prng => $prng2,
        data => $probs,
    );

    my $update_count
      = $object->update_values (
        1 => 10,
        5 => 0,
    );

    is $update_count, 2, 'got correct update count';

    my $expected = [@$probs];
    @{$expected}[1,5] = (10, 0);

    my $exp_sum = 0;
    $exp_sum += $_ foreach @$probs;
    $exp_sum -= ($probs->[1] + $probs->[5]);
    $exp_sum += 10;

    my $data = $object->get_data;

    is_deeply
      $data,
      $expected,
      'got expected data after modifying values';

    is $object->get_sum, $exp_sum, 'got expected sum';
    
    $object2->update_values (
        1 => 10,
        5 => 0,
    );
    $expected = [map {$object2->draw1} (1..10)];
    my $got   = [map {$object->draw1}  (1..10)];
    is_deeply $got, $expected, 'draws match after updates - indexed and not';
    
    my $idata = $object->{data};
    my $prng3 = Math::Random::MT::Auto->new (seed => 2345);
    my $object3 = Statistics::Sampler::Multinomial::Indexed->new (
        prng => $prng3,
        data => $probs,
    );
    is_deeply $object->{index}, $object3->{index}, 'updated index';
}

#  should be same as non-indexed
sub test_draw_n_samples_with_mask {
    my $probs = [
        1, 5, 2, 6, 3, 5, 10
    ];
    
    my $prng   = Math::Random::MT::Auto->new (seed => 2345);
    my $object = Statistics::Sampler::Multinomial::Indexed->new (
        prng => $prng,
        data => $probs,
    );

    my $mask = [1,2];  #  mask second and third items
    my $expected_draws = [20, 0, 0, 122, 64, 111, 183];
    my $draws = $object->draw_n_samples_with_mask(500, $mask);

    SKIP: {
        use Config;
        skip 'prng sequence differs under 32 bit ints', 2
          if $Config{ivsize} == 4;
        is_deeply
          $draws,
          $expected_draws,
          'got expected draws using draw_n_samples_with_mask method';
    }
    
}


1;
