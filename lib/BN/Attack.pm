package BN::Attack;
use strict;
use warnings;
use Storable qw( dclone );

my $attacks;

sub get {
   my ($class, $key, $weap) = @_;
   return unless $key;
   $attacks ||= BN::File->json('BattleAbilities.json');
   my $att = $attacks->{$key} or return;
   $att = bless dclone($att), $class;
   $att->{_tag} = $key;
   $att->{_name} = BN::Text->get($att->{name}) || $key;

   if (my $stats = delete $att->{stats}) {
      while (my ($k,$v) = each %$stats) {
         $att->{$k} = $v;
      }
   }

   my $unit_tag;
   if ($weap) {
      $unit_tag = $weap->{_unit_tag};
      if (my $stats = $weap->{stats}) {
         while (my ($k,$v) = each %$stats) {
            $att->{$k} //= ref($v) ? dclone($v) : $v;
         }
      }
   }

   my $reqs = delete $att->{reqs};
   $att->{z_reqs} = $reqs->{$unit_tag} if $reqs && $unit_tag;

   return $att;
}

BN->simple_accessor('tag');
BN->simple_accessor('name');
BN->simple_accessor('icon', 'icon');
BN->simple_accessor('cooldown', 'abilityCooldown');
BN->simple_accessor('globalcooldown', 'globalCooldown');
BN->simple_accessor('preptime', 'chargeTime');
BN->simple_accessor('target_area', 'targetArea');
BN->simple_accessor('damage_area', 'damageArea');
BN->simple_accessor('min_range', 'minRange');
BN->simple_accessor('max_range', 'maxRange');

BN->accessor(range => sub {
   my ($att) = @_;
   my $min = $att->{minRange} or return;
   my $max = $att->{maxRange} or return;
   $max += $att->{rangeBonus} if $att->{rangeBonus};
   return ($min == $max) ? $min : "$min-$max";
});

my %lof = (
   0 => 'Contact',
   1 => 'Direct',
   2 => 'Precise',
   3 => 'Indirect',
);

BN->accessor(lof => sub {
   my ($att) = @_;
   my $lof = $att->{lineOfFire};
   $lof = $lof{$lof} if defined $lof;
   if (my $dir = $att->{attackDirection}) {
      $lof .= ' (Back)' if $dir eq 'back';
   }
   if (my $target = $att->{targetArea}) {
      if (my $type = $target->{type}) {
         $lof .= ' (Fixed)' if $type eq 'Weapon';
      }
   }
   return $lof;
});

BN->accessor(numattacks => sub {
   my ($att) = @_;
   my $num = ($att->{shotsPerAttack}||1) * ($att->{attacksPerUse}||1);
   return $num > 1 ? $num : undef;
});

BN->accessor(armorpiercing => sub {
   my ($att) = @_;
   my $ap = $att->{armorPiercingPercent} or return;
   return if $ap < 0;
   return $ap * 100;
});

BN->accessor(notes => sub {
   my ($att) = @_;
   my @notes;
   if (my $range = $att->{maxRangeModATK}) {
      push @notes, sprintf("%+d {{Offense}} at max range", $range);
   }
   if (my $min = $att->{minHPPercent}) {
      push @notes, "Cannot lower HP below $min%";
   }
   return unless @notes;
   return join('<br>', @notes);
});

BN->multi_accessor('effects', 'dot', 'dotduration', 'dottype',
sub {
   my ($att) = @_;
   my $efflist = $att->{statusEffects} or return;
   my ($effects, $dot, $dotduration, $dottype);
   my @effects;
   foreach my $tag (sort keys %$efflist) {
      my $val = $efflist->{$tag};
      if ($tag =~ /^dot_fire_(\d+)_turn/) {
         $dot = 'true';
         $dotduration = $1;
         $dottype = 'fire';
         push @effects, "{{FireDOT|chance=$val|duration=$1}}";
      }
      elsif ($tag =~ /^dot_poison_(\d+)_turn$/) {
         $dot = 'true';
         $dotduration = $1;
         $dottype = 'poison';
         push @effects, "{{PoisonDOT|chance=$val|duration=$1}}";
      }
      elsif ($tag =~ /^frozen_(\d+)_turn$/) {
         push @effects, "{{Freeze|chance=$val|duration=$1}}";
      }
      elsif ($tag =~ /^stun_(\d+)_turn$/) {
         push @effects, "{{Stun|chance=$val|duration=$1}}";
      }
      else {
         push @effects, "$tag=$val";
      }
   }
   $effects = join('<br>', @effects) if @effects;
   return ($effects, $dot, $dotduration, $dottype);
});

BN->accessor(dmgtype => sub {
   my ($att) = @_;
   my $type = $att->{damageType} or return;
   die 'Weird damage type' unless @$type == 1;
   $type = $type->[0];
   if ($type eq 'Fire') {
      if (my $dottype = $att->dottype()) {
         $type = 'Poison' if $dottype eq 'poison';
      }
   }
   return $type;
});

BN->multi_accessor('mindmg', 'maxdmg', sub {
   my ($att) = @_;
   my $base_min = $att->{base_damage_min} or return;
   my $base_max = $att->{base_damage_max} or return;
   my $dmg = $att->{damage} || 0;
   my $mult = $att->{damageFromWeapon} // 1;
   my $min = int($base_min * $mult) + $dmg;
   my $max = int($base_max * $mult) + $dmg;
   return ($min, $max);
});

sub damage {
   my ($att, $power) = @_;
   my ($min, $max) = $att->adjusted_dmg($power);
   my $type = $att->dmgtype();
   my $num = $att->numattacks();
   $max .= " (x$num)" if $num;
   return $type ? "{{$type|$min-$max}}" : "$min-$max";
}

sub adjusted_dmg {
   my ($att, $power) = @_;
   my $mult = 1 + ($power || 0) * ($att->{damageFromUnit} // 1) / 50;
   return (int($att->mindmg() * $mult), int($att->maxdmg() * $mult));
}

sub offense {
   my ($att, $bonus) = @_;
   return ($att->{attack} || 0) + ($att->{base_ATK} || 0)
      + ($bonus || 0) * ($att->{attackFromUnit} // 1);
}

BN->accessor(ammoused => sub {
   my ($att) = @_;
   if (my $ammo = $att->{ammo}) {
      return if $ammo < 0;
   }
   return $att->{ammoRequired};
});

my %critmap = (
   Air         => '[[:Category:Air|Aircraft]]',
   Aircraft    => '[[:Category:Air|Aircraft]]',
   Artillery   => '[[:Category:Artillery|Artillery]]',
   Critter     => '[[:Category:Critters|Critters]]',
   Defense     => '[[:Category:Defense|Defense]]',
   I17Ancient  => '[[Experiment X17]]',
   Soldier     => '[[:Category:Soldiers|Soldiers]]',
   Tank        => '[[:Category:Tanks|Tanks]]',
   Vehicle     => '[[:Category:Vehicles|Vehicles]]',
   Zombie      => '[[:Category:Infected|Infected]]',
);

sub crit {
   my ($att, $bonus, $maxbonus) = @_;
   my $mult = $att->{critFromUnit} // 1;
   my $crit = int(($att->{criticalHitPercent} || 0) + ($bonus || 0) * $mult
      + ($att->{base_critPercent} || 0) * ($att->{critFromWeapon} // 1));
   my @crit;
   push @crit, $crit . '%';
   if (my $mods = $att->{criticalBonuses}) {
      foreach my $targ (sort keys %$mods) {
         my $val = $crit + $mods->{$targ};
         my $targname = $critmap{$targ} || $targ;
         push @crit, "$val% vs. $targname";
      }
   }
   if ($maxbonus) {
      if (!$mult) {
         push @crit, 'No rank bonus';
      }
      elsif ($mult == 1) {
         push @crit, '+ rank bonus';
      }
      else {
         push @crit, sprintf('+%.0f%% of rank bonus', $mult*100);
      }
   }
   return join('<br>', @crit);
}

BN->accessor(rank => sub {
   my ($att) = @_;
   my $rank = 1;
   my $reqs = $att->{z_reqs} or return $rank;
   my $prereqs = $reqs->{prereq} or return $rank;
   foreach my $key (sort keys %$prereqs) {
      my $prereq = $prereqs->{$key} or die;
      my $t = $prereq->{_t} or die;
      die unless $t eq 'UnitLevelPrereqConfig';
      $rank = $prereq->{level} or die;
   }
   return $rank;
});

BN->accessor(targets => sub {
   my ($att) = @_;
   my $targets = $att->{targets} or return;
   return join(', ', sort @$targets);
});

BN->accessor(cost => sub {
   my ($att) = @_;
   my $reqs = $att->{z_reqs} or return;
   return BN->format_amount(delete($reqs->{cost}), $reqs->{buildTime});
});

sub rank_mods {
   my ($att, $unit) = @_;
   my %mods;
   my @ranks = $unit->ranks();
   my $mult = $att->{attackFromUnit} // 1;
   onemod(\%mods, 'accuracy', $att->rank(),
      map { ($_->accuracy() || 0) * $mult } @ranks);
   $mult = $att->{damageFromUnit} // 1;
   onemod(\%mods, 'power', $att->rank(),
      map { ($_->power() || 0) * $mult } @ranks);
   if (@ranks > 6 && @ranks < 9) {
      my $dot = $att->dot();
      for my $i (@ranks+1 .. 9) {
         $mods{"damage$i"} = '-';
         $mods{"offense$i"} = '-';
         $mods{"dot$i"} = '-' if $dot;
      }
   }
   return unless %mods;
   return \%mods;
}

sub onemod {
   my ($mods, $tag, $rank, @vals) = @_;
   if (@vals >= 2 && !$vals[0] && $vals[1] != 5) {
      my $step = $vals[1];
      for my $i (2 .. $#vals) {
         if ($i*$step != $vals[$i]) {
            undef $step;
            last;
         }
      }
      if (defined $step) {
         $mods->{$tag} = $step;
         return;
      }
   }
   for my $i ($rank-1 .. $#vals) {
      $mods->{$tag . ($i+1)} = $vals[$i] if $vals[$i] != 5*$i;
   }
}

my $damage_animation;
BN->accessor(damage_animation_config => sub {
   my ($att) = @_;
   my $type = $att->{damageAnimationType} or return;
   $damage_animation ||= BN::File->json('DamageAnimConfig.json');
   return $damage_animation->{$type};
});

sub damage_animation {
   my ($att) = @_;
   my $dmg = $att->damage_animation_config() or return;
   return $dmg->{front};
}

sub back_damage_animation {
   my ($att) = @_;
   my $dmg = $att->damage_animation_config() or return;
   return $dmg->{back};
}

sub filename {
   my ($att, $unit) = @_;
   my $file = $unit->shortname();
   if ($unit->side() eq 'Hostile' && $unit->level()) {
      $file .= '_' if $file =~ /\d$/;
      $file .= $unit->level();
   }
   $file .= '_' . $att->name();
   $file =~ s/\W+//g;
   return $file;
}

1 # end BN::Attack
