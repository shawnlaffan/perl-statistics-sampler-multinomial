package Statistics::Sampler::Multinomial::Indexed;

use 5.014;
use warnings;
use strict;

our $VERSION = '0.87';

use Carp;
use Ref::Util qw /is_arrayref/;
use List::Util qw /min sum/;
use List::MoreUtils qw /first_index/;
use Scalar::Util qw /blessed looks_like_number/;

use POSIX qw /ceil floor log2 logb/;

use parent qw /Statistics::Sampler::Multinomial/;

sub new {
    my $pkg = shift;
    my $self = Statistics::Sampler::Multinomial->new(@_);
    bless $self, __PACKAGE__;
    
    $self->build_index;
    
    return $self;
}


#  Build a tree based index of cumulative values.
#  This will help the single draw methods.
#  Idea from 
#  https://www.chiark.greenend.org.uk/~sgtatham/algorithms/cumulative.html
sub build_index {
    my $self = shift;
    my $data = $self->{data};

    my $max_depth = 1 + logb (scalar @$data);

    # each index entry contains the cumulative sum of its terminals
    # and each level is half the length of the one below 
    my @indexed;

    #  bottom is just the data
    $indexed[$max_depth] = $data;  
    
    foreach my $i (0 .. $#$data) {
        #  could use integer pragma - may be faster?
        my $value = $data->[$i];
        my $idx = int ($i / 2);
        foreach my $level (reverse (0 .. $max_depth-1)) {
            $indexed[$level][$idx] += $value;
            $idx = int ($idx / 2);
        }
    }
    
    $self->{index} = \@indexed;

    return;
}

sub draw {
    my ($self) = @_;

    my $prng = $self->{prng};

    my $data  = $self->{data}
      // croak 'it appears setup has not been run yet';

    return 0 if @$data == 1;

    my $indexed = $self->{index};
    my $norm    = $indexed->[0][0];

    my $rand = $prng->rand * $norm;
    my $rand_orig = $rand;

    #  climb down the index tree
    #  start from 1 as 0 has single value
    my $level = 1;
    # current array items
    my $left  = 0;
    my $right = 1;

    while ($level < $#$indexed) {
        my ($leftval, $rightval)
          = @{$indexed->[$level]}[$left, $right];
        if ($rand <= $indexed->[$level][$left]) {
            #  descending left
            $left  *= 2;
            $right  = $left + 1;
        }
        else {
            #  descending right,
            #  so update target since left part
            #  of tree not in these sums
            $rand -= $indexed->[$level][$left];
            $left  = $right * 2;
            $right = $left  + 1;
        }
        $level++;
    }

    return $rand <= $data->[$left] ? $left : $right;    
}


sub update_values {
    my ($self, %args) = @_;
    
    if (!defined $self->{sum}) {
        $self->_initialise;
    }

    my $data = $self->{data};
    my $max_depth = 1 + logb (scalar @$data);
    my $indexed = $self->{index};

    my $count = 0;
    foreach my $iter (keys %args) {
        croak "iter $iter is not numeric"
          if !looks_like_number $iter;
        my $diff = $args{$iter} - ($data->[$iter] // 0);
        $self->{sum} += $diff;
        $data->[$iter] = $args{$iter};
        
        #  update the index
        my $idx = int ($iter / 2);
        foreach my $level (reverse (0 .. $max_depth-1)) {
            $indexed->[$level][$idx] += $diff;
            $idx = int ($idx / 2);
        }

        $count ++;
    }

    return $count;
}


1;
