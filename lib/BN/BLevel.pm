package BN::BLevel;
use strict;
use warnings;

sub new {
   my ($class, $level, $num) = @_;
   die unless ref($level) eq 'HASH';
   bless $level, $class;
   $level->{_level} = $num;
   return $level;
}

BN->simple_accessor('level');
BN->simple_accessor('input', 'input');
BN->simple_accessor('output', 'output');
BN->simple_accessor('xp_output', 'XPoutput');
BN->simple_accessor('queue_size', 'maximumHealingQueueSize');
BN->simple_accessor('time', 'time');

BN->accessor(cost => sub {
   my ($level) = @_;
   return BN->flatten_amount(delete($level->{upgradeCost}),
      delete($level->{upgradeTime}));
});

1 # end BN::BLevel
