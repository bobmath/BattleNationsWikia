package BN::Unit;
use strict;
use warnings;

my $units;
my $json_file = 'BattleUnits.json';

sub all {
   my ($class) = @_;
   $units ||= BN::File->json($json_file);
   return map { $class->get($_) } sort keys %$units;
}

sub get {
   my ($class, $key) = @_;
   return unless $key;
   $units ||= BN::File->json($json_file);
   my $unit = $units->{$key} or return;
   if (ref($unit) eq 'HASH') {
      bless $unit, $class;
      $unit->{_tag} = $key;
      my $name = BN::Text->get($unit->{name}) || $key;
      $name =~ s/^Speciment/Specimen/;
      $unit->{_name} = $name;
   }
   return $unit;
}

sub get_by_name {
   my ($class, $name) = @_;
   return unless defined $name;
   foreach my $unit ($class->all()) {
      return $unit if $unit->name() eq $name || $unit->shortname() eq $name;
   }
   return;
}

BN->simple_accessor('tag');
BN->simple_accessor('name');
BN->simple_accessor('building_level', 'buildingLevel');
BN->simple_accessor('side', 'side');
BN->simple_accessor('size', 'size');
BN->simple_accessor('icon', 'icon');
BN->simple_accessor('back_icon', 'backIcon');
BN->simple_accessor('animation', 'frontIdleAnimation');
BN->simple_accessor('back_animation', 'backIdleAnimation');
BN->simple_accessor('visibility_prereq', 'visibilityPrereq');

BN->accessor(shortname => sub {
   my ($unit) = @_;
   return BN::Text->get($unit->{shortName}) // $unit->{_name};
});

my %unit_names;
BN->accessor(enemy_name => sub {
   my ($unit) = @_;
   my $name = $unit->{_name};
   return $name unless ($unit->{side}||'') eq 'Hostile';
   unless (%unit_names) {
      foreach my $u (BN::Unit->all()) {
         my $side = $u->{side} or next;
         $unit_names{$u->name()} |= 1 if $side eq 'Player';
         $unit_names{$u->name()} |= 2 if $side eq 'Hostile';
      }
   }
   if ($unit_names{$name} == 3) {
      $name .= ($name =~ /^Frontier /) ? ' (civilian)' : ' (enemy)';
   }
   return $name;
});

sub wikilink {
   my ($unit) = @_;
   my $ename = $unit->enemy_name();
   my $name = $unit->{_name};
   return ($name eq $ename) ? "[[$name]]" : "[[$ename|$name]]";
}

sub description {
   my ($unit) = @_;
   return BN::Text->get($unit->{desc});
}

my %blocking = (
   0 => 'None',
   1 => 'Partial',
   2 => 'Blocking',
);

BN->accessor(blocking => sub {
   my ($unit) = @_;
   return $blocking{$unit->{blocking}};
});

my %ignore_types;
$ignore_types{$_} = 1 foreach qw(
   Airc
   Ani
   FlyingCritter
   Hospital
   Inf
   MissileStrike
   Sol
   VRB
   Veh
   Wimp
   ZombieCandidate
);

BN->accessor(type => sub {
   my ($unit) = @_;
   my $types = $unit->{tags} or return;
   my @types;
   foreach my $type (@$types) {
      if ($type eq 'Zombie')        { push @types, 'Infected' }
      elsif (!$ignore_types{$type}) { push @types, $type }
   }
   return unless @types;
   return join('-', @types);
});

BN->accessor(maxabil =>, sub {
   my ($unit) = @_;
   my $max = 0;
   if (my $stats = $unit->{stats}) {
      foreach my $stat (@$stats) {
         if (my $slots = $stat->{abilitySlots}) {
            $max = $slots if $slots > $max;
         }
      }
   }
   return $max;
});

BN->list_accessor(weapons => sub {
   my ($unit) = @_;
   my $weapons = delete $unit->{weapons} or return;
   my $tag = $unit->{_tag};
   my @weapons;
   foreach my $key (qw( primary secondary )) {
      my $weapon = delete $weapons->{$key} or next;
      push @weapons, BN::Weapon->new($weapon, $key, $tag);
   }
   foreach my $key (sort keys %$weapons) {
      push @weapons, BN::Weapon->new($weapons->{$key}, $key, $tag);
   }
   return @weapons;
});

my %immune = (
   Cold     => '{{Cold}} Cold',
   Fire     => '{{FireDOT}} Fire',
   Frozen   => '{{Freeze}} Freeze',
   Poison   => '{{PoisonDOT}} Poison',
   Stun     => '{{Stun}} Stun',
);

BN->accessor(immunities => sub {
   my ($unit) = @_;
   my $immune = $unit->{statusEffectImmunities} or return;
   my @immune = map { $immune{$_} || $_ } @$immune or return;
   return join('<br>', sort @immune);
});

BN->list_accessor(ranks => sub {
   my ($unit) = @_;
   my $stats = delete $unit->{stats} or return;
   my $n;
   return map { BN::Rank->new($_, ++$n) } @$stats;
});

BN->accessor(build_cost => sub {
   my ($unit) = @_;
   return BN->flatten_amount(delete($unit->{cost}), $unit->{buildTime});
});

BN->accessor(heal_cost => sub {
   my ($unit) = @_;
   return BN->flatten_amount(delete($unit->{healCost}), $unit->{healTime});
});

sub building {
   my ($unit) = @_;
   return $unit->{_building} if exists $unit->{_building};
   foreach my $u (BN::Unit->all()) {
      $u->{_building} = undef;
   }
   foreach my $build (BN::Building->all()) {
      next if $build->tag() eq 'comp_milUnit_testbarracks';
      foreach my $u ($build->units()) {
         $u->{_building} = $build->tag();
      }
   }
   return $unit->{_building};
}

sub from_missions {
   my ($unit) = @_;
   if (!exists $unit->{_from_missions}) {
      foreach my $u (BN::Unit->all()) {
         $u->{_from_missions} = undef;
      }
      foreach my $mis (BN::Mission->all()) {
         my $rewards = $mis->{rewards} or next;
         my $units = $rewards->{units} or next;
         foreach my $key (sort keys %$units) {
            my $u = BN::Unit->get($key) or next;
            push @{$u->{_from_missions}}, $mis->tag();
         }
      }
   }
   return unless $unit->{_from_missions};
   return @{$unit->{_from_missions}};
}

BN->list_accessor(mission_reqs => sub {
   my ($unit) = @_;
   my @missions;
   foreach my $prereq ($unit->prereqs()) {
      my $t = $prereq->{_t} or next;
      next unless $t eq 'CompleteMissionPrereqConfig';
      my $id = $prereq->{missionId} or next;
      push @missions, $id;
   }
   return @missions;
});

BN->accessor(heal_building => sub {
   my ($unit) = @_;
   my $tags = $unit->{tags} or return;
   foreach my $tag (@$tags) {
      if    ($tag eq 'Hospital') { return 'hospital' }
      elsif ($tag eq 'VRB')      { return 'vehicle' }
   }
   return;
});

BN->accessor(rewards => sub {
   my ($unit) = @_;
});

sub level {
   my ($unit) = @_;
   return $unit->{_level} if exists $unit->{_level};
   BN::Prereqs->calc_levels();
   return $unit->{_level};
}

sub prereqs {
   my ($unit) = @_;
   my $prereqs = $unit->{prereq} or return;
   return map { $prereqs->{$_} } sort keys %$prereqs;
}

BN->accessor(max_armor => sub {
   my ($unit) = @_;
   my $max = 0;
   foreach my $rank ($unit->ranks()) {
      my $armor = $rank->armor() or next;
      $max = $armor if $armor > $max;
   }
   return $max;
});

BN->accessor(max_crit => sub {
   my ($unit) = @_;
   my $max = 0;
   foreach my $rank ($unit->ranks()) {
      my $crit = $rank->crit() or next;
      $max = $crit if $crit > $max;
   }
   return $max;
});

BN->accessor(max_ability_slots => sub {
   my ($unit) = @_;
   my $max = 0;
   foreach my $rank ($unit->ranks()) {
      my $slots = $rank->ability_slots() or next;
      $max = $slots if $slots > $max;
   }
   return $max;
});

BN->accessor(total_attacks => sub {
   my ($unit) = @_;
   my $total = 0;
   foreach my $weap ($unit->weapons()) {
      $total += $weap->attacks();
   }
   return $total;
});

BN->accessor(other_reqs => sub {
   my ($unit) = @_;
   my @reqs;
   my $build = $unit->building() // '';
   push @reqs, '[[Prestigious Academy]]'
      if $build eq 'comp_milUnit_prestige';
   if (my $prereqs = $unit->{prereq}) {
      foreach my $key (sort keys %$prereqs) {
         my $prereq = $prereqs->{$key} or next;
         my $t = $prereq->{_t} or next;
         if ($t eq 'HasCompositionPrereqConfig') {
            my $tag = $prereq->{compositionName} or next;
            next if $tag eq $build;
            my $b = BN::Building->get($tag) or next;
            push @reqs, $b->wikilink();
         }
         elsif ($t eq 'HaveAnyOfTheseStructuresPrereqConfig') {
            my $tags = $prereq->{buildings} or next;
            my @any;
            foreach my $tag (@$tags) {
               my $b = BN::Building->get($tag) or next;
               push @any, $b->wikilink();
            }
         }
         elsif ($t eq 'CompleteMissionPrereqConfig') {
            my $mis = BN::Mission->get($prereq->{missionId}) or next;
            push @reqs, $mis->wikilink();
         }
      }
   }
   if (my $prereqs = $unit->{visibilityPrereq}) {
      foreach my $key (sort keys %$prereqs) {
         my $prereq = $prereqs->{$key} or next;
         my $t = $prereq->{_t} or next;
         if ($t eq 'ActiveTagPrereqConfig') {
            push @reqs, 'Promotional';
         }
      }
   }
   if (!$build) {
      if (my ($mis_id) = $unit->from_missions()) {
         my $mis = BN::Mission->get($mis_id);
         push @reqs, $mis->wikilink() if $mis;
      }
   }
   push @reqs, 'Boss Strike' if $unit->boss_strike();
   return unless @reqs;
   return join '<br>', sort @reqs;
});

sub boss_strike {
   my ($unit) = @_;
   if (!exists $unit->{_boss_strike}) {
      $_->{_boss_strike} = undef foreach BN::Unit->all();
      foreach my $strike (BN::BossStrike->all()) {
         foreach my $tier ($strike->tiers()) {
            my $rewards = $tier->rewards() or next;
            my $units = $rewards->{units} or next;
            foreach my $id (sort keys %$units) {
               my $u = BN::Unit->get($id) or next;
               $u->{_boss_strike} = $strike->tag();
            }
         }
      }
   }
   return BN::BossStrike->get($unit->{_boss_strike});
}

my %encounters;
sub encounters {
   my ($unit) = @_;
   if (!%encounters) {
      foreach my $enc (BN::Encounter->all()) {
         foreach my $id ($enc->units()) {
            push @{$encounters{$id}}, $enc->tag();
         }
      }
   }
   my $enc = $encounters{$unit->tag()} or return;
   return @$enc;
}

sub enemy_levels {
   my %levels;
   foreach my $enc (BN::Encounter->all()) {
      my $level = $enc->level() or next;
      foreach my $id ($enc->units()) {
         $levels{$id} = $level
            if !exists($levels{$id}) || $levels{$id} > $level;
      }
   }

   foreach my $unit (BN::Unit->all()) {
      next unless $unit->{side} eq 'Hostile';
      $unit->{z_prereqs} = [] if $unit->{z_prereqs};
      $unit->{_level} = $1 if $unit->{_tag} =~ /_(\d+)$/;
      if (!$unit->{_level} || $unit->{_level} <= 1) {
         $unit->{_level} = $levels{$unit->{_tag}};
      }
   }

   my %override = (
      fr_guy_chainsaw_ignorable        => undef,
      fr_guy_dynamite_ignorable        => undef,
      fr_guy_hunter_ignorable          => undef,
      fr_guy_pyro_ignorable            => undef,
      fr_guy_shotgun_ignorable         => undef,
      raptor_zombie_enemy_20           => undef,
      raptor_zombie_enemy_40           => undef,
      s_raider_sniper_tutorial         => 3,
      veh_raider_mammoth_armored       => 25,
   );
   while (my ($key, $val) = each %override) {
      my $unit = BN::Unit->get($key) or next;
      $unit->{_level} = $val;
   }
}

my %deploy_tags = (
   Ignorable   => 'Ignorables',
   Zombie      => 'Infected',
);
my $battle_config;
BN->accessor(deploy_limit => sub {
   my ($unit) = @_;
   $battle_config ||= BN::File->json('BattleConfig.json');
   my $tags = $unit->{tags} or return;
   my ($limit, $what);
   foreach my $tag (@$tags) {
      my $info = $battle_config->{settings}{unitTagMetaData}{$tag} or next;
      my $tag_limit = $info->{deployLimit} or next;
      if (!defined($limit) || $limit > $tag_limit) {
         $limit = $tag_limit;
         $what = $deploy_tags{$tag};
      }
   }
   $limit .= ' ' . $what if $what;
   return $limit;
});

1 # end BN::Unit
