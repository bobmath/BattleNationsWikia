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

   my $reqs = delete $att->{reqs};

   if ($weap) {
      my $unit_tag = $weap->{_unit_tag};
      $att->{z_reqs} = $reqs->{$unit_tag} if $reqs && $unit_tag;
      if (my $stats = $weap->{stats}) {
         while (my ($k,$v) = each %$stats) {
            $att->{$k} //= ref($v) ? dclone($v) : $v;
         }
      }
      return if $weap->{_max_rank} && $att->rank() > $weap->{_max_rank};
   }

   return $att;
}

BN->simple_accessor('tag');
BN->simple_accessor('name');
BN->simple_accessor('icon', 'icon');
BN->simple_accessor('preptime', 'chargeTime');
BN->simple_accessor('target_area', 'targetArea');
BN->simple_accessor('damage_area', 'damageArea');
BN->simple_accessor('min_range', 'minRange');
BN->simple_accessor('unit_offense_mult', 'attackFromUnit');
BN->simple_accessor('unit_damage_mult', 'damageFromUnit');
BN->simple_accessor('unit_crit_mult', 'critFromUnit');

BN->accessor(max_range => sub {
   my ($att) = @_;
   my $max = $att->{maxRange} or return;
   $max += $att->{rangeBonus} if $att->{rangeBonus};
   if (my $area = $att->{targetArea}) {
      if ($area->{type} eq 'Weapon') {
         my $amax = 1;
         foreach my $sq (@{$area->{data}}) {
            my $pos = $sq->{pos} or next;
            my $y = -$pos->{y};
            $amax = $y if $y > $amax;
         }
         $max = $amax if $amax < $max;
      }
   }
   return $max;
});

BN->accessor(range => sub {
   my ($att) = @_;
   my $min = $att->{minRange} or return;
   my $max = $att->max_range() or return;
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
   my @mods;
   if (my $dir = $att->{attackDirection}) {
      push @mods, 'Back' if $dir eq 'back';
   }
   if (my $target = $att->{targetArea}) {
      if (my $type = $target->{type}) {
         push @mods, 'Fixed' if $type eq 'Weapon';
      }
      push @mods, 'Random' if $target->{random};
   }
   $lof .= ' (' . join(', ', @mods) . ')' if @mods;
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
      push @notes, sprintf("%+d {{Offense}} range mod", $range);
   }
   if (my $min = $att->{minHPPercent}) {
      push @notes, "Cannot lower HP below $min%";
   }
   #if ($att->{capture}) {
   #   push @notes, 'Can apprehend civilians';
   #}
   return unless @notes;
   return join('<br>', @notes);
});

BN->multi_accessor('effects', 'dotduration', 'dottype', sub {
   my ($att) = @_;
   my $efflist = $att->{statusEffects} or return;
   my ($effects, $dotduration, $dottype);
   my @effects;
   foreach my $tag (sort keys %$efflist) {
      my $chance = $efflist->{$tag};
      if (my $eff = BN::StatusEffect->get($tag)) {
         my $icon = $eff->icon();
         my $dur = $eff->duration();
         if ($icon eq 'FireDOT') {
            $dottype = $eff->diminish() ? 'fire' : 'napalm';
         }
         elsif ($icon eq 'PoisonDOT') {
            $dottype = 'poison';
         }
         elsif ($icon eq 'Breach') {
            $dottype = 'breach';
         }
         $dotduration = $dur if $dottype;
         push @effects, "{{$icon|chance=$chance|duration=$dur}}";
      }
      else {
         push @effects, "$tag ($chance%)";
      }
   }
   $effects = join('<br>', @effects) if @effects;
   return ($effects, $dotduration, $dottype);
});

BN->accessor(dmgtype => sub {
   my ($att) = @_;
   my $type = $att->{damageType} or return;
   die 'Weird damage type' unless @$type == 1;
   return $type->[0];
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
   Civilian    => '[[:Category:Civilians Non-Player|Civilians]]',
   Critter     => '[[:Category:Critters|Critters]]',
   Defense     => '[[:Category:Defense|Defense]]',
   Gunboat     => '[[:Category:Boats|Gunboats]]',
   I17Ancient  => '[[Experimental Construct]]',
   Metal       => '[[:Category:Metal|Metal]]',
   Soldier     => '[[:Category:Soldiers|Soldiers]]',
   Sub         => '[[:Category:Subs|Submarines]]',
   Tank        => '[[:Category:Tanks|Tanks]]',
   Vehicle     => '[[:Category:Vehicles|Vehicles]]',
   Zombie      => '[[:Category:Infected|Infected]]',
);

BN->accessor(base_crit => sub {
   my ($att) = @_;
   return int(($att->{criticalHitPercent} // 0)
      + ($att->{base_critPercent} // 0) * ($att->{critFromWeapon} // 1));
});

sub crit {
   my ($att, $bonus) = @_;
   my $mult = $att->{critFromUnit} // 1;
   my $crit = int($att->base_crit() + ($bonus // 0) * $mult);
   my @crit;
   push @crit, $crit . '%';
   if (my $mods = $att->{criticalBonuses}) {
      foreach my $targ (sort keys %$mods) {
         my $val = $crit + $mods->{$targ};
         my $targname = $critmap{$targ} || $targ;
         push @crit, "$val% vs. $targname";
      }
   }
   return join('<br>', @crit);
}

sub crit_bonuses {
   my ($att) = @_;
   my $mods = $att->{criticalBonuses} or return;
   my @crit;
   foreach my $targ (sort keys %$mods) {
      my $val = $mods->{$targ} or next;
      my $name = $critmap{$targ} || $targ;
      push @crit, sprintf('%s %+d', $name, $val);
   }
   return unless @crit;
   return join('; ', @crit);
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
   return BN->flatten_amount(delete($reqs->{cost}), $reqs->{buildTime});
});

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
   if ($unit->side() ne 'Player' && $unit->level()) {
      $file .= '_' if $file =~ /\d$/;
      $file .= $unit->level();
   }
   $file .= '_' . $att->name();
   $file =~ s/\W+//g;
   return $file;
}

BN->accessor(cooldown => sub {
   my ($att) = @_;
   return $att->filter_cooldown($att->{abilityCooldown});
});

BN->accessor(globalcooldown => sub {
   my ($att) = @_;
   return $att->filter_cooldown($att->{globalCooldown});
});

sub filter_cooldown {
   my ($att, $cooldown) = @_;
   return unless $cooldown;
   my $ammo = $att->{ammo} or return $cooldown;
   my $used = $att->{ammoRequired} or return $cooldown;
   my $reload = $att->{reloadTime} or return $cooldown;
   return $ammo == $used && $reload >= $cooldown ? undef : $cooldown;
}

BN->accessor(suppression => sub {
   my ($att) = @_;
   my @mods;
   if (defined(my $mult = $att->{damage_distraction})) {
      push @mods, 'x' . $mult if $mult != 1;
   }
   if (my $add = $att->{damage_distractionBonus}) {
      push @mods, '+' . $add;
   }
   return unless @mods;
   return join ' ', @mods;
});

1 # end BN::Attack
