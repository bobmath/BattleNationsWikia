package BN::BossStrike;
use strict;
use warnings;

my $strikes;
my $json_file = 'CoopBossEventConfig.json';

sub all {
   my ($class) = @_;
   $strikes ||= BN::JSON->read($json_file);
   return map { $class->get($_) }
      sort grep { !/_qa|_test|boss0/i } keys %$strikes;
}

sub get {
   my ($class, $key) = @_;
   return unless $key;
   $strikes ||= BN::JSON->read($json_file);
   my $strike = $strikes->{$key} or return;
   if (ref($strike) eq 'HASH') {
      bless $strike, $class;
      $strike->{_tag} = $key;
      $strike->{_name} = BN::Text->get($strike->{uiConfig}{eventTitle});
   }
   return $strike;
}

BN->simple_accessor('tag');
BN->simple_accessor('name');

BN->list_accessor(tiers => sub {
   my ($strike) = @_;
   my $tiers = delete $strike->{tierInfo} or return;
   my $def = delete $strike->{defaultProgressCost};
   my $n;
   return map { BN::Tier->new($_, ++$n, $def) } @$tiers;
});

1 # end BN::BossStrike
