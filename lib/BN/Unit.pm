package BN::Unit;
use strict;
use warnings;
use Storable qw( dclone );
@BN::Unit::ISA = qw( BN::Prereqs );

my $units;

my %load_map = (
   affil       => '_affiliation',
   level       => '_enemy_level',
   name        => '_name',
   shortname   => '_shortname',
   side        => 'side',
);

sub load {
   return if $units;
   $units = BN::File->json('BattleUnits.json');
   open my $F, '<', 'unitinfo' or return;
   local $/ = '*';
   local $_;
   while (<$F>) {
      chomp;
      s/^\s*(\S+)\s*// or next;
      my $id = $1;
      my $unit = $units->{$id};
      if (!$unit) {
         my $base_id = $id;
         $base_id =~ s/\((.*)\)$// or next;
         my $tag = $1;
         my $orig = $units->{$base_id} or next;
         $unit = dclone($orig);
         $unit->{_cloneof} = $base_id;
         if ($tag eq 'hostile') {
            $orig->{_hasclone} = $id;
            $unit->{side} = 'Hostile';
            $unit->{_affiliation} = 'rebel';
         }
         delete $unit->{transformationTable};
         $units->{$id} = $unit;
      }

      s/\s+/ /g;
      if (s/\[\[(.*?)\]\]/ /) {
         $unit->{_wiki_page} = $1;
      }

      my @parts = split /(\w+)\s*=\s*/, $_;
      shift(@parts);
      while (@parts) {
         my $key = shift(@parts);
         my $val = shift(@parts) // '';
         $key = $load_map{$key} or next;
         $val =~ s/ $//;
         $unit->{$key} = $val;
      }
   }
   close $F;
}

sub all {
   my ($class) = @_;
   $class->load() unless $units;
   return map { $class->get($_) } sort keys %$units;
}

sub get {
   my ($class, $key, $hostile) = @_;
   return unless $key;
   $class->load() unless $units;
   my $unit = $units->{$key} or return;
   if ($hostile && $unit->{_hasclone}) {
      $key = $unit->{_hasclone};
      $unit = $units->{$key} or return;
   }
   if (ref($unit) eq 'HASH') {
      bless $unit, $class;
      $unit->{_tag} = $key;
      $unit->{_name} ||= BN::Text->get($unit->{name}) || $key;
      $unit->{_name} =~ s/\s+$//;
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
BN->simple_accessor('side', 'side');
BN->simple_accessor('size', 'size');
BN->simple_accessor('icon', 'icon');
BN->simple_accessor('back_icon', 'backIcon');
BN->simple_accessor('animation', 'frontIdleAnimation');
BN->simple_accessor('back_animation', 'backIdleAnimation');
BN->simple_accessor('preferred_row', 'preferredRow');
BN->simple_accessor('building_level', 'buildingLevel');

BN->accessor(shortname => sub {
   my ($unit) = @_;
   return BN::Text->get($unit->{shortName}) // $unit->{_name};
});

my %unit_names;
BN->accessor(wiki_page => sub {
   my ($unit) = @_;
   my $name = $unit->{_name};
   return $name unless ($unit->{side}||'') eq 'Hostile';
   if ($name =~ /^Specimen [a-z]\d+ ['"](.+)['"]$/) {
      $name = $1;
      $name =~ s/^(?:Proto-|Advanced|Archetype)\s*//;
      return $name . ' (enemy)';
   }
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
   my ($unit, $text) = @_;
   my $ename = $unit->wiki_page();
   $text //= $unit->{_name};
   return (length($text) == 0 || $text eq $ename) ? "[[$ename]]"
      : "[[$ename|$text]]";
}

sub shortlink {
   my ($unit) = @_;
   my $ename = $unit->wiki_page();
   my $sname = $unit->shortname();
   return $ename eq $sname ? "[[$ename]]" : "[[$ename|$sname]]";
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
   Crossover2
   FlyingCritter
   Hospital
   Inf
   MissileStrike
   SRB
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
   my $tag = $unit->{_cloneof} || $unit->{_tag};
   my $max = $unit->{_cloneof} ? 1 : undef;
   my @weapons;
   foreach my $key (qw( primary secondary )) {
      my $weapon = delete $weapons->{$key} or next;
      push @weapons, BN::Weapon->new($weapon, $key, $tag, $max);
   }
   foreach my $key (sort keys %$weapons) {
      push @weapons, BN::Weapon->new($weapons->{$key}, $key, $tag, $max);
   }
   if ($max) {
      @weapons = grep { $_->attacks() } @weapons;
   }
   return @weapons;
});

my %immune = (
   Acid        => '{{Acid}} Acid',
   Breach      => '{{Breach}} Breach',
   Cold        => '{{ColdEnvironment}} Cold Environment',
   Fire        => '{{FireDOT}} Fire',
   Flammable   => '{{ExplosiveAmp}} Explosive',
   Freeze      => 'xxx', # incorrectly coded in game files
   Frozen      => '{{Freeze}} Freeze',
   Plague      => '{{Plague}} Plague',
   Poison      => '{{PoisonDOT}} Poison',
   Quake       => '{{Quake}} Quake',
   Shatter     => '{{Shatter}} Shatter',
   Shell       => '{{Shell}} Shell',
   Stun        => '{{Stun}} Stun',
);

BN->accessor(immunities => sub {
   my ($unit) = @_;
   my $immune = $unit->{statusEffectImmunities} or return;
   my @immune;
   foreach my $imm (@$immune) {
      my $icon = $immune{$imm} || $imm;
      next if $icon eq 'xxx';
      (my $sort = $icon) =~ s/^.*\}\s*//;
      push @immune, [ $sort, $icon ];
   }
   return join('<br>', map { $_->[1] } sort { $a->[0] cmp $b->[0] } @immune);
});

BN->list_accessor(ranks => sub {
   my ($unit) = @_;
   my $stats = delete $unit->{stats} or return;
   splice @$stats, 1 if $unit->{_cloneof};
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

sub building_req {
   my ($unit) = @_;
   my $bld_id = $unit->building() or return;
   my $bld = BN::Building->get($bld_id) or return;
   my $name = $bld->wikilink();
   if ($bld->levels() > 1) {
      $name .= ' level ' . ($unit->{buildingLevel} || 1);
   }
   return $name;
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
      elsif ($tag eq 'SRB')      { return 'ship' }
   }
   return;
});

sub prereqs {
   my ($unit) = @_;
   my @prereqs;
   foreach my $field (qw( prereq visibilityPrereq)) {
      my $prereqs = $unit->{$field} or next;
      push @prereqs, map { $prereqs->{$_} } sort keys %$prereqs;
   }
   return @prereqs;
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
   if (my $tags = $unit->{tags}) {
      foreach my $tag (@$tags) {
         push @reqs, '[[Infection Test Facility]]' if $tag eq 'Inf';
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
      foreach my $id ($enc->unit_ids(), $enc->player_unit_ids()) {
         $levels{$id} = $level
            if !exists($levels{$id}) || $levels{$id} > $level;
      }
   }
   foreach my $unit (BN::Unit->all()) {
      next if $unit->{side} eq 'Player';
      if (my $level = $unit->{_enemy_level}) {
         $unit->{_level} = $level;
         next;
      }
      $unit->{_level} = $1 if $unit->{_tag} =~ /_(\d+)(?:\(.*\))?$/;
      if (!$unit->{_level} || $unit->{_level} <= 1) {
         $unit->{_level} = $levels{$unit->{_tag}}
            and $unit->{_guessed_level} = 1;
      }
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

sub spawned_unit {
   my ($unit) = @_;
   return BN::Unit->get($unit->{deathSpawnedUnit});
}

1 # end BN::Unit
