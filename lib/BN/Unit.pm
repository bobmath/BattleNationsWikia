package BN::Unit;
use strict;
use warnings;
use Storable qw( dclone );

my $units;

my @clone_ids = qw(
   air_attack_helicopter
   i17_veh_tank_railgun
   s_arctic_trooper
   s_arsonist
   s_bazooka
   s_bounty_hunter
   s_chem_trooper
   s_commando
   s_crowd_control_trooper
   s_demolition
   s_dragoon
   s_flame
   s_flame_heavy
   s_grenadier
   s_grenadier_bio
   s_gunner
   s_hitman
   s_hunter
   s_hunter_eagleEye
   s_juggernaut
   s_laser_machingun
   s_mgshield
   s_midrange_agent
   s_minigunner
   s_mortar
   s_mortar_turtleShell
   s_ninja
   s_officer
   s_ranger
   s_rocket_light
   s_rpg
   s_saboteur
   s_shock
   s_shotgunner
   s_sniper
   s_sniper_heavy
   s_sniper_special
   s_sniper_super
   s_trooper
   s_trooper_bigGameHunter
   s_trooper_cryo
   s_trooper_dragoon_heavy
   s_trooper_fire_ice
   s_trooper_jetpack
   s_trooper_lightning
   s_trooper_missileStrike
   s_trooper_plasma
   s_trooper_railgun
   s_trooper_saboteur_heavy
   s_trooper_specialAgent
   s_trooper_veteran
   s_veh_portableWall
   veh_anti_aircraft_gun_premium
   veh_anti_aircraft_gun_regular
   veh_artillery
   veh_artillery_heavy
   veh_artillery_light
   veh_artillery_mega
   veh_artillery_napalm
   veh_artillery_super
   veh_bike
   veh_boomBus
   veh_cannon_plasma
   veh_combine_tank
   veh_dunerider
   veh_flame_turret
   veh_flametank_light
   veh_guntruck
   veh_jeep_humvee
   veh_jeep_tow
   veh_machine_gun_turret
   veh_mgtank
   veh_mlrs
   veh_mlrs_heavy
   veh_recon_heavy
   veh_recon_light
   veh_rockettruck_light
   veh_sports_bike
   veh_tank_arctic
   veh_tank_arctic_heavy
   veh_tank_basilisk
   veh_tank_chem_heavy
   veh_tank_chem_light
   veh_tank_cryo
   veh_tank_flame_heavy
   veh_tank_heavier
   veh_tank_heavy
   veh_tank_heavy_gold
   veh_tank_laser
   veh_tank_light
   veh_tank_medium
   veh_tank_mega
   veh_tank_mini
   veh_tank_plasma
   veh_tank_super
   veh_tank_tesla
   veh_tank_wheeled
   veh_tankdestroyer
   veh_trackedmortar
   veh_trebuchet
);

sub load {
   unless ($units) {
      $units = BN::File->json('BattleUnits.json');
      foreach my $id (@clone_ids) {
         my $unit = $units->{$id} or next;
         my $clone = dclone($unit);
         my $clone_id = $id . '(hostile)';
         $unit->{_hasclone} = $clone_id;
         $clone->{_cloneof} = $id;
         $clone->{side} = 'Hostile';
         $clone->{_affiliation} = 'rebel';
         delete $clone->{transformationTable};
         $units->{$clone_id} = $clone;
      }
   }
}

sub all {
   my ($class) = @_;
   $class->load() unless $units;
   return map { $class->get($_) } sort keys %$units;
}

my %name = (
   's_dragoon(hostile)'             => 'Rebel Dragoon',
);

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
      my $name = $name{$key} || BN::Text->get($unit->{name}) || $key;
      if ($name =~ /^Specimen/) {
         $name =~ s/Speciment/Specimen/;
         $name =~ s/'/"/g;
      }
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
BN->simple_accessor('side', 'side');
BN->simple_accessor('size', 'size');
BN->simple_accessor('icon', 'icon');
BN->simple_accessor('back_icon', 'backIcon');
BN->simple_accessor('animation', 'frontIdleAnimation');
BN->simple_accessor('back_animation', 'backIdleAnimation');
BN->simple_accessor('visibility_prereq', 'visibilityPrereq');
BN->simple_accessor('preferred_row', 'preferredRow');
BN->simple_accessor('building_level', 'buildingLevel');

my %shortname = (
);

BN->accessor(shortname => sub {
   my ($unit) = @_;
   return $shortname{$unit->{_tag}}
      // BN::Text->get($unit->{shortName}) // $unit->{_name};
});

my %wiki_page = (
   's_hunter(hostile)'              => 'Rebel Hunter',
   boss_goliath_tank_leftside       => 'Multi-Launch Rocket System (Left)',
   boss_goliath_tank_leftside_mis   => 'Multi-Launch Rocket System (Left) (Mission)',
   boss_goliath_tank_main           => 'Goliath Tank (Main)',
   boss_goliath_tank_main_mis       => 'Goliath Tank (Main) (Mission)',
   boss_goliath_tank_rightside      => 'Multi-Launch Rocket System (Right)',
   boss_goliath_tank_rightside_mis  => 'Multi-Launch Rocket System (Right) (Mission)',
   def_sandbag                      => 'Sandbags (enemy)',
   fr_guy_chainsaw_ignorable        => 'Frontier Lumberjack (ignorable)',
   fr_guy_dynamite_ignorable        => 'Frontier Engineer (ignorable)',
   fr_guy_hunter_ignorable          => 'Frontier Hunter (ignorable)',
   fr_guy_pyro_ignorable            => 'Frontier Pyro (ignorable)',
   fr_guy_shotgun_ignorable         => 'Frontier Minuteman (ignorable)',
   hero_ancient_robot_30            => 'Ancient Construct (Boss Strike)',
   hero_ancient_robot_45            => 'Ancient Construct (Boss Strike)',
   hero_ancient_robot_60            => 'Ancient Construct (Boss Strike)',
   hero_cast_morgan_buff            => 'Lt. Morgan (buffed)',
   hero_cast_morgan_duels           => 'Lt. Morgan (duels)',
   hero_cast_perkins_duels          => 'Perkins (duels)',
   hero_cast_perkins_flamecostume   => 'Perkins (flame)',
   hero_cast_perkins_passive        => 'Perkins (passive)',
   hero_cast_perkins_raidercostume  => 'Perkins (raider)',
   hero_cast_perkins_tank           => 'Perkins (tank)',
   hero_cast_perkins_zombie         => 'Perkins (zombie)',
   hero_cast_ramsey                 => 'Ramsey',
   hero_cast_ramsey_50              => 'Ramsey',
   hero_cast_ramsey_buff            => 'Ramsey',
   hero_cast_ramsey_hostage         => 'Ramsey (hostage)',
   hero_raider_crazyblades_ignorable   => 'Crazy Blades (ignorable)',
   hero_raider_sarin_ignorable      => 'Sarin (ignorable)',
   hero_raider_tronk_14_ignorable   => 'Tronk (ignorable)',
   hero_raider_warlord_ignorable    => 'Warlord Gantas (ignorable)',
   hero_raider_warlord_passive      => 'Warlord Gantas (passive)',
   raptor_zombie_enemy_20           => 'Shredder (unused)',
   raptor_zombie_enemy_40           => 'Shredder (unused)',
   s_boar_militia                   => 'Wild Boar (militia)',
   s_commando_ignore                => 'Commando (ignorable)',
   s_raider_dustwalker              => 'Dust Walker (enemy)',
   s_raider_dustwalker_40           => 'Dust Walker (enemy)',
   s_raider_firebreather            => 'Firebreather (enemy)',
   s_raider_firebreather_40         => 'Firebreather (enemy)',
   sw_veh_artillery                 => 'Silver Wolf Artillery',
   sw_veh_artillery_20              => 'Silver Wolf Artillery',
   sw_veh_artillery_5               => 'Silver Wolf Artillery',
   sw_veh_artillery_player          => 'Wolf Artillery',
   tf2_hero_demoman                 => 'Demoman (Team Fortress 2)',
   tf2_hero_heavy                   => 'Heavy (Team Fortress 2)',
   tf2_hero_pyro                    => 'Pyro (Team Fortress 2)',
   tf2_hero_scout                   => 'Scout (Team Fortress 2)',
   tf2_hero_soldier                 => 'Soldier (Team Fortress 2)',
);

my %unit_names;
BN->accessor(wiki_page => sub {
   my ($unit) = @_;
   my $name = $wiki_page{$unit->{_tag}};
   return $name if $name;
   $name = $unit->{_name};
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
   Flammable   => '{{Flammable}} Flammable',
   Frozen      => '{{Freeze}} Freeze',
   Plague      => '{{Plague}} Plague',
   Poison      => '{{PoisonDOT}} Poison',
   Shatter     => '{{Shatter}} Shatter',
   Stun        => '{{Stun}} Stun',
);

BN->accessor(immunities => sub {
   my ($unit) = @_;
   my $immune = $unit->{statusEffectImmunities} or return;
   my @immune = map { $immune{$_} || $_ } sort @$immune or return;
   return join('<br>', @immune);
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
   }
   return;
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
   #push @reqs, '[[Infection Test Facility]]' if $unit->{transformationTable};
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

my %enemy_level = (
   'air_attack_helicopter(hostile)' => 10,
   's_trooper_jetpack(hostile)'     => 5,
   air_spiderwasp_striker           => 45,
   hero_cast_cassidy_unlimited_ammo => 56,
   hero_cast_morgan                 => 15,
   hero_cast_ramsey_rage_buff       => 30,
   hero_raider_warlord              => 30,
   hero_spiderwasp_queen_super      => 70,
   s_ninja_npc                      => 64,
   s_raider_sniper_tutorial         => 3,
   s_sandworm_elder                 => 27,
   veh_raider_mammoth_armored       => 25,
);

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
      if (my $level = $enemy_level{$unit->{_tag}}) {
         $unit->{_level} = $level;
         next;
      }
      $unit->{_level} = $1 if $unit->{_tag} =~ /_(\d+)$/;
      if (!$unit->{_level} || $unit->{_level} <= 1) {
         $unit->{_level} = $levels{$unit->{_tag}};
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

1 # end BN::Unit
