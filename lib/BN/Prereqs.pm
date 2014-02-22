package BN::Prereqs;
use strict;
use warnings;

sub calc_levels {
   foreach my $unit (BN::Unit->all()) {
      if (my $build = $unit->building()) {
         push @{$unit->{z_prereqs}}, { type=>'BN::Building', ids=>[$build] };
      }
      elsif (my @mis = $unit->from_missions()) {
         push @{$unit->{z_prereqs}}, { type=>'BN::Mission', ids=>\@mis };
      }
   }

   my @has_prereqs;
   foreach my $class (qw[ BN::Unit BN::Building
      BN::Mission BN::Mission::Completion ])
   {
      foreach my $obj ($class->all()) {
         $obj->{_level} = undef;
         add_prereq($obj, $_) foreach $obj->prereqs();
         push @has_prereqs, $obj if $obj->{z_prereqs};
      }
   }

   foreach my $id (qw[ p01_LVLUP_010_UnitPromotion1 ]) {
      my $mis = BN::Mission->get($id) or next;
      $mis->{_level} = 1;
   }

   my $changed;
   do {
      $changed = 0;
      foreach my $obj (@has_prereqs) {
         foreach my $prereq (@{$obj->{z_prereqs}}) {
            my $level = 99;
            my $type = $prereq->{type};
            foreach my $id (@{$prereq->{ids}}) {
               my $other = $type->get($id) or next;
               my $olevel = $other->{_level} // 0;
               $level = $olevel if $olevel < $level;
            }
            if ($level < 99 && $level > 0 &&
               (!defined($obj->{_level}) || $level > $obj->{_level}))
            {
               $obj->{_level} = $level;
               $changed = 1;
            }
         }
      }
   } while $changed;
}

sub add_prereq {
   my ($obj, $prereq) = @_;
   return unless $prereq;
   return if $prereq->{inverse};
   my $t = $prereq->{_t} or return;
   my ($type, $ids, $id);
   if ($t eq 'LevelPrereqConfig') {
      my $level = $prereq->{level} or return;
      return if $level < 1;
      $level = 71 if $level > 71;
      $obj->{_level} = $level;
   }
   elsif ($t eq 'CompleteMissionPrereqConfig') {
      $type = 'Mission::Completion';
      $id = $prereq->{missionId};
   }
   elsif ($t eq 'CompleteAnyMissionPrereqConfig') {
      $type = 'Mission::Completion';
      $ids = $prereq->{missionIds};
   }
   elsif ($t eq 'ActiveMissionPrereqConfig') {
      $type = 'Mission';
      $ids = $prereq->{missionIds};
   }
   elsif ($t eq 'CreateStructurePrereqConfig'
      || $t eq 'CollectStructurePrereqConfig')
   {
      $type = 'Building';
      $id = $prereq->{structureType};
   }
   elsif ($t eq 'HasCompositionPrereqConfig') {
      $type = 'Building';
      $id = $prereq->{compositionName};
   }
   elsif ($t eq 'HaveAnyOfTheseStructuresPrereqConfig') {
      $type = 'Building';
      $ids = $prereq->{buildings};
   }
   elsif ($t eq 'BuildingLevelPrereqConfig') {
      $type = 'Building';
      $ids = $prereq->{compositionIds};
   }
   elsif ($t eq 'HaveOneOfTheseStructuresPrereqConfig') {
      $type = 'Building';
      my $counts = $prereq->{buildingCounts} or return;
      $ids = [ sort keys %$counts ];
   }
   elsif ($t eq 'CollectProjectPrereqConfig'
      || $t eq 'StartProjectPrereqConfig')
   {
      $type = 'Unit';
      $id = $prereq->{projectId};
   }
   push @{$obj->{z_prereqs}}, { type=>"BN::$type", ids=>[$id] } if $id;
   push @{$obj->{z_prereqs}}, { type=>"BN::$type", ids=>[@$ids] } if $ids;
}

my %places = (
   AncientRuins1           => "[[Ancient Ruins]]",
   BOARS_RecoilRidge       => "[[Recoil Ridge]]",
   CrazyBladesBase         => "[[Blade's Base]]",
   FINAL_90_raiderFortress => "[[Warlord Gantas' Fortress]]",
   FINAL_raiderFortress    => "[[Warlord Gantas' Fortress]]",
   Marin                   => "[[Marin]]",
   MyLand                  => '[[Outpost]]',
   RFORT_90_raiderFortress => "[[Warlord Gantas' Fortress]]",
   SAVRR_RecoilRidge       => "[[Recoil Ridge]]",
   SarinBase               => "[[Sarin's Base]]",
   TronkBase               => "[[Tronk's Base]]",
   WORLD_MAP               => "[[World Map]]",
   WorldMap                => '[[World Map]]',
   boarLand                => "[[Boar Badlands]]",
   lightReconLand          => "[[Boar Badlands]]",
   npc_1                   => "[[Recoil Ridge]]",
   npc_2                   => "[[Recoil Ridge]]",
   raptorNest              => "[[Raptor Nest]]",
);

sub describe {
   my ($class, $prereq) = @_;
   my $t = $prereq->{_t} or return;
   if ($t eq 'LevelPrereqConfig') {
      my $level = $prereq->{level} or return;
      return "[[Levels#$level|Level $level]]";
   }
   elsif ($t eq 'HasCompositionPrereqConfig') {
      my $build = BN::Building->get($prereq->{compositionName}) or return;
      my $name = $build->wikilink() . count($prereq);
      return "Build $name";
   }
   elsif ($t eq 'CreateStructurePrereqConfig'
      || $t eq 'CollectStructurePrereqConfig')
   {
      my $bld = BN::Building->get($prereq->{structureType}) or return;
      my $name = $bld->wikilink() . count($prereq);
      return "Build $name";
   }
   elsif ($t eq 'HaveOneOfTheseStructuresPrereqConfig') {
      my $counts = $prereq->{buildingCounts} or return;
      my @bldgs;
      while (my ($id, $num) = each %$counts) {
         my $bld = BN::Building->get($id) or return;
         push @bldgs, $bld->wikilink() . count($num);
      }
      return unless @bldgs;
      return 'Build ' . join(' or ', sort @bldgs);
   }
   elsif ($t eq 'HaveAnyOfTheseStructuresPrereqConfig') {
      my $ids = $prereq->{buildings} or return;
      my @bldgs;
      foreach my $id (@$ids) {
         my $bldg = BN::Building->get($id) or return;
         push @bldgs, $bldg->wikilink() . count($prereq);
      }
      return unless @bldgs;
      return 'Build ' . join(' or ', @bldgs);
   }
   elsif ($t eq 'DefeatEncounterPrereqConfig'
      || $t eq 'DefeatEncounterSetPrereqConfig'
      || $t eq 'DefeatOccupationPrereqConfig'
      || $t eq 'FinishBattlePrereqConfig')
   {
      return 'Defeat encounter';
   }
   elsif ($t eq 'UnitsKilledPrereqConfig') {
      my $unit = BN::Unit->get($prereq->{unitId}) or return;
      my $name = $unit->wikilink() . count($prereq);
      return "Kill $name";
   }
   elsif ($t eq 'AttackNPCBuildingPrereqConfig') {
      my $bld = BN::Building->get($prereq->{compositionName}) or next;
      my $name = $bld->wikilink() . count($prereq);
      return "Attack $name";
   }
   elsif ($t eq 'CollectJobPrereqConfig') {
      my $job = BN::Job->get($prereq->{jobId}) or return;
      my $name = $job->name();
      if (my ($bldid) = $job->buildings()) {
         my $bld = BN::Building->get($bldid);
         my $bldname = $bld->name();
         $name = "[[$bldname#Goods|$name]]";
      }
      return "Make $name" . count($prereq);
   }
   elsif ($t eq 'TurnInPrereqConfig') {
      my $toll = BN->format_amount($prereq->{toll}) or return;
      return "Turn in $toll";
   }
   elsif ($t eq 'CollectProjectPrereqConfig') {
      my $unit = BN::Unit->get($prereq->{projectId}) or return;
      my $name = $unit->wikilink() . count($prereq);
      return "Train $name";
   }
   elsif ($t eq 'EnterOpponentLandPrereqConfig'
      || $t eq 'EnterStatePrereqConfig')
   {
      my $name = $prereq->{opponentId} || $prereq->{state};
      $name = $places{$name} || $name;
      return "Go to $name";
   }
   elsif ($t eq 'BuildingAssistedPrereqConfig') {
      my $bld = BN::Building->get($prereq->{compositionId}) or return;
      my $name = $bld->wikilink() . count($prereq);
      return "Assist $name";
   }
   elsif ($t eq 'MinPopulationCapacityPrereqConfig') {
      return "Population $prereq->{capacity}";
   }
   elsif ($t eq 'BuildingLevelPrereqConfig') {
      my $ids = $prereq->{compositionIds} or return;
      my $what = join ' or ', map { $_->wikilink() }
         map { BN::Building->get($_) } @$ids;
      return "Upgrade $what to level $prereq->{level}";
   }
   elsif ($t eq 'AddUnitGarrisonPrereqConfig') {
      return "Add $prereq->{count} units to garrisons";
   }
   elsif ($t eq 'DefensiveCoveragePrereqConfig') {
      return "Defend $prereq->{percent}% of buildings";
   }
   elsif ($t eq 'HaveLandExpansionsPrereqConfig') {
      return "Expand to $prereq->{count} spaces";
   }
   elsif ($t eq 'CompleteMissionPrereqConfig') {
      my $m = BN::Mission->get($prereq->{missionId}) or return;
      return 'Complete ' . $m->wikilink();
   }
   elsif ($t eq 'CompleteAnyMissionPrereqConfig'
      || $t eq 'ActiveMissionPrereqConfig')
   {
      my $ids = $prereq->{missionIds} or return;
      return 'Complete ' . join(' or ', map { $_->wikilink() }
         map { BN::Mission->get($_) } @$ids);
   }
   return "Other: $t";
}

sub count {
   my ($num) = @_;
   $num = $num->{count} if ref $num;
   return $num && $num > 1 ? " x $num" : '';
}

1 # end BN::Prereqs
