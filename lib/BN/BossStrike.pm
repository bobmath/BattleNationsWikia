package BN::BossStrike;
use strict;
use warnings;

my $strikes;
my $json_file = 'CoopBossEventConfig.json';

my %old_strikes;
$old_strikes{$_} = 1 foreach qw{
   boss0_event_raiders
   boss2_event_raiders_QA
   boss3_event_SW_QA
   boss4_event_zombies_QA
   boss5_event_SW_Animals_QA
   boss6_event_Rebels_Airplanes_QA
   boss7_event_SilverWolves2_QA
   coopBossEvent_integ_test_1
   coopBossEvent_integ_test_achieve
   coopBossEvent_integ_test_locked
   coopBossEvent_manual_test_1
   qa_functionality_test_event
};

sub all {
   my ($class) = @_;
   $strikes ||= BN::JSON->read($json_file);
   return map { $class->get($_) }
      sort grep { !$old_strikes{$_} } keys %$strikes;
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
