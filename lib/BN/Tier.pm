package BN::Tier;
use strict;
use warnings;

sub new {
   my ($class, $tier, $num, $default) = @_;
   die unless ref($tier) eq 'HASH';
   bless $tier, $class;
   $tier->{_tier} = $num;
   if (my $cost = delete($tier->{tierProgressCost}) || $default) {
      $tier->{_cost} = BN->flatten_amount($cost->{amount});
      $tier->{_points_awarded} = $cost->{awardedPoints};
   }
   return $tier;
}

BN->simple_accessor('tier');
BN->simple_accessor('cost');
BN->simple_accessor('points_awarded');
BN->simple_accessor('points_needed', 'requiredCompletionPoints');

BN->accessor(rewards => sub {
   my ($tier) = @_;
   return BN->flatten_amount(delete $tier->{rewards});
});

1 # end BN::Tier
