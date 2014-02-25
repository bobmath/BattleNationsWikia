package BN::Unit;
use strict;
use warnings;

my $units;
my $json_file = 'BattleUnits.json';

sub all {
   my ($class) = @_;
   $units ||= BN::JSON->read($json_file);
   return map { $class->get($_) } sort keys %$units;
}

sub get {
   my ($class, $key) = @_;
   return unless $key;
   $units ||= BN::JSON->read($json_file);
   my $unit = $units->{$key} or return;
   if (ref($unit) eq 'HASH') {
      bless $unit, $class;
      $unit->{_tag} = $key;
      my $name = BN::Text->get($unit->{name});
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
BN->simple_accessor('icon', 'icon');

BN->accessor(shortname => sub {
   my ($unit) = @_;
   return BN::Text->get($unit->{shortName});
});

sub wikilink {
   my ($unit) = @_;
   return "[[$unit->{_name}]]";
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

BN->accessor(mods => sub {
   my ($unit) = @_;
   my $ranks = [ $unit->ranks() ];
   my %mods;
   onemod(\%mods, 'accuracy', $ranks);
   onemod(\%mods, 'power', $ranks);
   return unless %mods;
   return \%mods;
});

sub onemod {
   my ($mods, $tag, $ranks) = @_;
   my @vals = map { $_->{$tag} || 0 } @$ranks;
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
   for my $i (0 .. $#vals) {
      $mods->{$tag . ($i+1)} = $vals[$i] if $vals[$i] != 5*$i;
   }
}

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
   return unless @reqs;
   return join '<br>', sort @reqs;
});

1 # end BN::Unit
