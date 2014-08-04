package BN::BossStrike;
use strict;
use warnings;

my $strikes;
my $json_file = 'CoopBossEventConfig.json';

my %old_strikes;
$old_strikes{$_} = 1 foreach qw{
   boss0_event_raiders
   coopBossEvent_integ_test_1
   coopBossEvent_integ_test_achieve
   coopBossEvent_integ_test_locked
   coopBossEvent_manual_test_1
   qa_functionality_test_event
};

sub all {
   my ($class) = @_;
   $strikes ||= BN::File->json($json_file);
   return map { $class->get($_) }
      sort grep { !/_qa$/i && !$old_strikes{$_} } keys %$strikes;
}

sub get {
   my ($class, $key) = @_;
   return unless $key;
   $strikes ||= BN::File->json($json_file);
   my $strike = $strikes->{$key} or return;
   if (ref($strike) eq 'HASH') {
      bless $strike, $class;
      $strike->{_tag} = $key;
      $strike->{_name} = BN::Text->get($strike->{uiConfig}{eventTitle})
         || $key;
   }
   return $strike;
}

BN->simple_accessor('tag');
BN->simple_accessor('name');
BN->simple_accessor('icon' => 'missionIcon');

BN->accessor(short_desc => sub {
   my ($strike) = @_;
   return BN::Text->get($strike->{uiConfig}{eventShortDesc});
});

BN->accessor(long_desc => sub {
   my ($strike) = @_;
   return BN::Text->get($strike->{uiConfig}{eventLongDesc});
});

BN->accessor(prize_desc => sub {
   my ($strike) = @_;
   return BN::Text->get($strike->{uiConfig}{topPrizeDesc});
});

BN->list_accessor(tiers => sub {
   my ($strike) = @_;
   my $tiers = delete $strike->{tierInfo} or return;
   my $def = delete $strike->{defaultProgressCost};
   my $n;
   return map { BN::Tier->new($_, ++$n, $def) } @$tiers;
});

1 # end BN::BossStrike
