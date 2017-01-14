use strict;
use warnings;
use 5.010;
use English qw /-no_match_vars/;

use rlib;
use Test::Most;
use Statistics::Sampler::Multinomial;
use Math::Random::MT::Auto;

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


sub test_croakers {
    my $prng = Math::Random::MT::Auto->new;
    my ($result, $e, $object);

    $object = eval {
        Statistics::Sampler::Multinomial->new (data => undef);
    };
    $e = $EVAL_ERROR;
    ok $e, 'error when data arg not passed or is undef';

    $object = eval {
        Statistics::Sampler::Multinomial->new (data => {});
    };
    $e = $EVAL_ERROR;
    ok $e, 'error when data arg not an array ref';

    $object = eval {
        Statistics::Sampler::Multinomial->new (
            data => [1,2],
            prng => $prng,
        );
    };
    $e = $EVAL_ERROR;
    ok !$e, 'no error when prng arg passed';
    
    $result = eval {$object->draw};
    $e = $EVAL_ERROR;
    ok !$e, 'no error when draw called before _initialise';

    $object = eval {
        Statistics::Sampler::Multinomial->new (
            data => {a => 2},
            prng => $prng,
        );
    };
    $e = $EVAL_ERROR;
    ok $e, 'error when passed a hash ref as the data arg';

    $object = eval {
        Statistics::Sampler::Multinomial->new (
            data => 'some scalar',
            prng => $prng,
        );
    };
    $e = $EVAL_ERROR;
    ok $e, 'error when passed a scalar as the data arg';
    
    $object = eval {
        Statistics::Sampler::Multinomial->new (
            data => [-1, 2, 4],
            prng => $prng,
        );
    };
    $e = $EVAL_ERROR;
    ok $e, 'error when passed a negative value in the data';
}

