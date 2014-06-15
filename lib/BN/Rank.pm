package BN::Rank;
use strict;
use warnings;

sub new {
   my ($class, $rank, $num) = @_;
   die unless ref($rank) eq 'HASH';
   bless $rank, $class;
   $rank->{_rank} = $num;
   return $rank;
}

BN->simple_accessor('rank');
BN->simple_accessor('hp', 'hp');
BN->simple_accessor('armor', 'armorHp');
BN->simple_accessor('defense', 'defense');
BN->simple_accessor('bravery', 'bravery');
BN->simple_accessor('dodge', 'dodge');
BN->simple_accessor('accuracy', 'accuracy');
BN->simple_accessor('power', 'power');
BN->simple_accessor('ability_slots', 'abilitySlots');
BN->simple_accessor('crit', 'critical');
BN->simple_accessor('sp', 'levelCutoff');
BN->simple_accessor('prerank_req', 'minDropLevel');
BN->simple_accessor('armor_mods', 'armorDamageMods');
BN->simple_accessor('damage_mods', 'damageMods');
BN->simple_accessor('armor_type', 'armorDefStyle');

BN->accessor(cost => sub {
   my ($rank) = @_;
   return BN->format_amount(delete($rank->{levelUpCost}),
      delete($rank->{levelUpTime}), '<br>');
});

BN->accessor(rewards => sub {
   my ($rank) = @_;
   return BN->flatten_amount(delete($rank->{rewards}));
});

sub uv {
   my ($rank) = @_;
   return $rank->{pv} // 0;
}

sub gold_reward {
   my ($rank) = @_;
   my $rewards = $rank->rewards() or return 0;
   return $rewards->{gold} // 0;
}

sub sp_reward {
   my ($rank) = @_;
   my $rewards = $rank->rewards() or return 0;
   return $rewards->{SP} // 0;
}

BN->accessor(level_req => sub {
   my ($rank) = @_;
   my $prereqs = $rank->{prereqsForLevel} or return;
   my $level;
   foreach my $prereq (values %$prereqs) {
      my $t = $prereq->{_t} or next;
      die 'unknown level prereq' unless $t eq 'LevelPrereqConfig';
      $level = $prereq->{level};
   }
   return $level;
});

BN->accessor(level_up_rewards => sub {
   my ($rank) = @_;
   return BN->flatten_amount(delete $rank->{levelUpRewards});
});

1 # end BN::Rank
