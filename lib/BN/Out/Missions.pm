package BN::Out::Missions;
use strict;
use warnings;
use BN::Out;
use Data::Dump qw( dump );

my %old_missions;
$old_missions{$_} = 1 foreach qw(
   p01_BK2RR_010_RaidersBattle2
   p01_BK2RR_020_BuildPillbox
   p01_BK2RR_030_TrainGrenadier
   p01_BK2RR_040_ReturnRecoilRidge
   p01_BK2RR_050_BattleRecoilRidge
   p01_BK2RR_051_HeroesReturn1
   p01_BK2RR_052_HeroesReturn2
   p01_BK2RR_053_HeroesReturn3
   p01_BK2RR_060_HelpAdventurer
   p01_BK2RR_061_SandboxOpen
   p01_BUILD_040_CollectSupplyDrops
   p01_BUILD_070_BuildBootCamp
   p01_BUILD_090_BuildShelter
   p01_BUILD_100_TeachCamera
   p01_BUILD_110_RaiderEncounters
   p01_BUILD_130_BuildStoneQuarry
   p01_BUILD_140_BuildResourceDepot
   p01_BUILD_150_CollectTaxes
   p01_BUILD_280_BuildBunker2
   p01_BUILD_290_BuildBunker2
   p01_BUILD_510_BuildHospital
   p01_FARMS_010_BuildFarm1
   p01_HOSP_010_QueueSomething
   p01_INTRO_040_BuildShelter
   p01_NEWINTRO_140_BuildHospital
   p01_NEWINTRO_143_StartAdvHospital
   p01_RTANK_010_RaiderScouts
   p01_RTANK_060_BuildToolShop
   p01_RTANK_070_MakeTools
   p01_UPBLD_010_BuildingUpgradeLvl1
   p01_UPBLD_010_BuildingUpgradeLvl1_LateGame
   p01_UPBLD_020_BuildingUpgradeLvl2
   p01_UPBLD_020_BuildingUpgradeLvl2_LateGame
   p01_ZOEY1_010_BuildHovel
);

my ($curr_page, $curr_file);

sub write {
   my @groups;
   foreach my $mis (BN::Mission->all()) {
      next if $old_missions{$mis->tag()};
      my $level = $mis->level() or next;
      my $grp = int(($mis->level() - 1) / 10);
      push @{$groups[$grp]}, $mis;
   }
   $curr_page = 0;
   foreach my $group (@groups) {
      $curr_file = sprintf 'Level %d-%d missions',
         $curr_page*10+1, $curr_page*10+10;
      my $filename = BN::Out->filename('missions', $curr_file);
      open my $F, '>:utf8', $filename or die;
      print $F $curr_file, "\n\n";
      sort_group($F, $group);
      ++$curr_page;
   }
   foreach my $mis (BN::Mission->all()) {
      my $file = BN::Out->filename('missions', $mis->level(), $mis->name());
      print $file, "\n";
      open my $F, '>', $file or die "Can't write $file: $!";;
      print $F dump($mis), "\n";
      close $F;
      BN::Out->checksum($file);
   }
}

my (%blocks, %followups);
sub sort_group {
   my ($F, $group) = @_;
   @$group = sort { $a->level() <=> $b->level() } @$group;
   foreach my $mis (@$group) {
      $blocks{$mis->tag()} = { before=>{}, after=>{}, missions=>[$mis] };
   }
   foreach my $id (sort keys %blocks) {
      my $block = $blocks{$id} or die;
      my $mis = $block->{missions}[0];
      foreach my $prereq (prereqs($mis)) {
         my $refblk = $blocks{$prereq} or next;
         $refblk->{after}{$mis->tag()} = 1;
         $block->{before}{$prereq} = 1;
      }
   }
   coalesce($_) foreach sort keys %blocks;
   print_block($F, $_) foreach sort block_compare keys %blocks;
   %blocks = ();
   %followups = ();
}

sub block_compare {
   my $amis = BN::Mission->get($a) or die;
   my $bmis = BN::Mission->get($b) or die;
   $amis->level() <=> $bmis->level() || $amis->name() cmp $bmis->name();
}

sub coalesce {
   my ($id) = @_;
   my $block = $blocks{$id} or return;

   while (1) {
      my $nextid;
      my $nextlev = 999;
      foreach my $checkid (keys %{$block->{after}}) {
         my $checkblk = $blocks{$checkid} or die;
         my $checkmis = $checkblk->{missions}[0];
         my $checklev = $checkmis->level();
         if ($checklev < $nextlev) {
            $nextlev = $checklev;
            $nextid = $checkid;
         }
         elsif ($checklev == $nextlev) {
            $nextid = undef;
         }
      }
      return unless $nextid;
      my $nextblk = $blocks{$nextid} or die;
      return if keys(%{$nextblk->{before}}) > 1;
      die unless $nextblk->{before}{$id};

      foreach my $refid (sort keys %{$block->{after}}) {
         my $refblk = $blocks{$refid} or die;
         delete $refblk->{before}{$id} or die;
      }

      foreach my $refid (sort keys %{$nextblk->{after}}) {
         my $refblk = $blocks{$refid} or die;
         delete $refblk->{before}{$nextid} or die;
         $refblk->{before}{$id} = 1;
      }

      my $lastmis = $block->{missions}[-1];
      delete $block->{after}{$nextid};
      $followups{$lastmis->tag()} = $block->{after} if %{$block->{after}};
      push @{$block->{missions}}, @{$nextblk->{missions}};
      $block->{after} = $nextblk->{after};
      delete $blocks{$nextid} or die;
   }
}

sub print_block {
   my ($F, $id) = @_;
   my $block = $blocks{$id} or die;
   return if $block->{mark};
   $block->{mark} = 1;
   print_block($F, $_) foreach sort block_compare keys %{$block->{before}};
   print_mission($F, $_) foreach @{$block->{missions}};
   print_followups($F, $block->{after});
   print $F "\n";
}

my %already_have;
sub print_mission {
   my ($F, $mis) = @_;
   print $F "===", $mis->name(), "===\n";
   my @prereqs;
   my $level = $mis->level();
   push @prereqs, "[[Levels#$level|Level $level]]";
   foreach my $prereq (prereqs($mis)) {
      push @prereqs, mission_link(BN::Mission->get($prereq));
   }
   print $F "Prereqs: ", join(', ', @prereqs), "\n" if @prereqs;

   foreach my $obj ($mis->objectives()) {
      my $t = $obj->{_t} or next;
      my $txt = describe($obj) or next;
      if ($txt =~ /^Build/) {
         next if $already_have{$txt}++;
      }
      print $F "* $txt\n";
   }

   if (my $rewards = $mis->rewards()) {
      print $F "Rewards: $rewards<br>\n";
   }

   my @unlocks;
   foreach my $obj ($mis->unlocks_buildings(), $mis->unlocks_units()) {
      push @unlocks, $obj->wikilink();
   }
   print $F "Unlocks: ", join(', ', @unlocks), "<br>\n" if @unlocks;

   print_followups($F, $followups{$mis->tag()});
}

sub print_followups {
   my ($F, $followups) = @_;
   return unless $followups && %$followups;
   my @followup = map { mission_link(BN::Mission->get($_)) }
      sort block_compare keys %$followups;
   print $F "Followups: ", join(', ', @followup), "\n" if @followup;
}

sub mission_link {
   my ($mis) = @_;
   my $page = '';
   my $num = int(($mis->level() - 1) / 10);
   if ($num != $curr_page) {
      my $lo = $num * 10 + 1;
      my $hi = $lo + 9;
      $hi = 65 if $hi > 65;
      $page = "Level $lo-$hi missions";
   }
   my $name = $mis->name();
   return "[[$page#$name|$name]]";
}

my (%full_prereqs, %min_prereqs);
sub prereqs {
   my ($mis) = @_;
   my $misid = $mis->tag();
   return @{$min_prereqs{$misid}} if $min_prereqs{$misid};
   my %prereqs;
   $prereqs{$misid} = 1;
   $full_prereqs{$misid} = \%prereqs;
   my @filtered;
   $min_prereqs{$misid} = \@filtered;

   my @prereqs;
   foreach my $prereq ($mis->prereqs(), $mis->completion()->prereqs()) {
      my $t = $prereq->{_t} or next;
      next if $prereq->{inverse};
      my $preid;
      if ($t eq 'CompleteMissionPrereqConfig') {
         $preid = $prereq->{missionId};
         next if $old_missions{$preid};
      }
      elsif ($t eq 'CompleteAnyMissionPrereqConfig'
         || $t eq 'ActiveMissionPrereqConfig')
      {
         my $ids = $prereq->{missionIds} or next;
         foreach my $testid (@$ids) {
            next if $old_missions{$testid};
            die "too many ids for $misid" if $preid;
            $preid = $testid;
         }
      }
      next unless $preid;
      my $m = BN::Mission->get($preid) or next;
      prereqs($m);
      my $p = $full_prereqs{$preid};
      while (my ($k,$v) = each %$p) {
         $prereqs{$k} = 1;
      }
      push @prereqs, { id=>$preid, full=>$p };
   }

   CHECK: foreach my $prereq (@prereqs) {
      my $preid = $prereq->{id};
      foreach my $other (@prereqs) {
         next if $other->{id} eq $preid || $other->{mark};
         if ($other->{full}{$preid}) {
            $prereq->{mark} = 1;
            next CHECK;
         }
      }
      push @filtered, $preid;
   }

   return @filtered;
}

my %places = (
   AncientRuins1           => "[[Ancient Ruins]]",
   BOARS_RecoilRidge       => "[[Recoil Ridge]]",
   BigfootHabitat          => "[[Bigfoot Country]]",
   CrazyBladesBase         => "[[Blade's Base]]",
   FINAL_90_raiderFortress => "[[Warlord Gantas' Fortress]]",
   FINAL_raiderFortress    => "[[Warlord Gantas' Fortress]]",
   FRNTR_Bernmoth          => "[[Bernmoth]]",
   FRNTR_Bernmoth_damaged  => "[[Bernmoth]]",
   FRNTR_Trotbeck          => "[[Trotbeck]]",
   FrontierBluff           => "[[Shigurman's Bluff]]",
   HunterHouse             => "[[Bogan's House]]",
   InsideInstallation17    => "[[Installation 17]]",
   Installation17          => "[[Installation 17]]",
   LabRuins                => "[[Ancient Laboratory]]",
   Marin                   => "[[Marin]]",
   MyLand                  => "[[Outpost]]",
   NewHaven                => "[[New Haven]]",
   RFORT_90_raiderFortress => "[[Warlord Gantas' Fortress]]",
   SABOT_rebels            => "[[Greenborough]]",
   SABOT_rebels_attackable => "[[Greenborough]]",
   SAVRR_RecoilRidge       => "[[Recoil Ridge]]",
   SWEAT_RecoilRidge       => "[[Recoil Ridge]]",
   SarinBase               => "[[Sarin's Base]]",
   Skarborough             => "[[Skarborough]]",
   Sundale                 => "[[Sundale]]",
   TronkBase               => "[[Tronk's Base]]",
   VaultRuins              => "[[Ancient Vault]]",
   WORLD_MAP               => "[[World Map]]",
   WorldMap                => "[[World Map]]",
   boarLand                => "[[Boar Badlands]]",
   frontierMap             => "[[Southern Frontier]]",
   frozenMap               => "[[Eastern Wastes]]",
   heartlandMap            => "[[Heartland]]",
   lightReconLand          => "[[Boar Badlands]]",
   npc_1                   => "[[Recoil Ridge]]",
   npc_2                   => "[[Recoil Ridge]]",
   raptorNest              => "[[Raptor Nest]]",
);

sub describe {
   my ($prereq) = @_;
   my $text = BN::Text->fetch($prereq->{objectiveText});
   my $t = $prereq->{_t} or return $text;
   if ($t eq 'LevelPrereqConfig') {
      my $level = $prereq->{level};
      return "[[Levels#$level|Level $level]]" if $level;
   }
   elsif ($t eq 'HasCompositionPrereqConfig') {
      my $build = BN::Building->get($prereq->{compositionName});
      return 'Build ' . $build->wikilink() . count($prereq) if $build;
   }
   elsif ($t eq 'CreateStructurePrereqConfig'
      || $t eq 'CollectStructurePrereqConfig')
   {
      my $build = BN::Building->get($prereq->{structureType});
      return 'Build ' . $build->wikilink() . count($prereq) if $build;
   }
   elsif ($t eq 'HaveOneOfTheseStructuresPrereqConfig') {
      if (my $counts = $prereq->{buildingCounts}) {
         my @bldgs;
         while (my ($id, $num) = each %$counts) {
            my $bld = BN::Building->get($id) or next;
            push @bldgs, $bld->wikilink() . count($num);
         }
         return 'Build ' . join(' or ', sort @bldgs) if @bldgs;
      }
   }
   elsif ($t eq 'HaveAnyOfTheseStructuresPrereqConfig') {
      if (my $ids = $prereq->{buildings}) {
         my @bldgs;
         foreach my $id (@$ids) {
            my $bldg = BN::Building->get($id) or next;
            push @bldgs, $bldg->wikilink() . count($prereq);
         }
         return 'Build ' . join(' or ', @bldgs) if @bldgs;
      }
   }
   elsif ($t eq 'DefeatEncounterPrereqConfig'
      || $t eq 'DefeatEncounterSetPrereqConfig'
      || $t eq 'DefeatOccupationPrereqConfig'
      || $t eq 'FinishBattlePrereqConfig')
   {
      return $text || 'Defeat encounter';
   }
   elsif ($t eq 'UnitsKilledPrereqConfig') {
      my $unit = BN::Unit->get($prereq->{unitId});
      return 'Kill ' . $unit->wikilink() . count($prereq) if $unit;
   }
   elsif ($t eq 'AttackNPCBuildingPrereqConfig') {
      my $bld = BN::Building->get($prereq->{compositionName});
      return 'Attack ' . $bld->wikilink() . count($prereq) if $bld;
   }
   elsif ($t eq 'CollectJobPrereqConfig') {
      if (my $job = BN::Job->get($prereq->{jobId})) {
         my $name = $job->name();
         my $verb = 'Make';
         if (my ($bldid) = $job->buildings()) {
            my $bld = BN::Building->get($bldid);
            my $bldname = $bld->name();
            $verb = 'Grow' if ($bld->gets_bonus()//'') =~ /Agricultural/;
            $name = "[[$bldname#Goods|$name]]";
         }
         return "$verb $name" . count($prereq);
      }
   }
   elsif ($t eq 'TurnInPrereqConfig') {
      my $toll = BN->format_amount($prereq->{toll});
      return "Turn in $toll" if $toll;
   }
   elsif ($t eq 'CollectProjectPrereqConfig') {
      my $unit = BN::Unit->get($prereq->{projectId});
      return 'Train ' . $unit->wikilink() . count($prereq) if $unit;
   }
   elsif ($t eq 'EnterOpponentLandPrereqConfig'
      || $t eq 'EnterStatePrereqConfig')
   {
      if (my $tag = ($prereq->{opponentId} || $prereq->{state})) {
         my $name = $places{$tag};
         return $text if !$name && $text;
         return 'Go to ' . ($name || $tag);
      }
   }
   elsif ($t eq 'BuildingAssistedPrereqConfig') {
      my $bld = BN::Building->get($prereq->{compositionId});
      return 'Assist ' . $bld->wikilink() . count($prereq) if $bld;
   }
   elsif ($t eq 'MinPopulationCapacityPrereqConfig') {
      return "Population $prereq->{capacity}";
   }
   elsif ($t eq 'BuildingLevelPrereqConfig') {
      if (my $ids = $prereq->{compositionIds}) {
         my $what = join ' or ', map { $_->wikilink() }
            map { BN::Building->get($_) } @$ids;
         return "Upgrade $what to level $prereq->{level}" if $what;
      }
   }
   elsif ($t eq 'AddUnitGarrisonPrereqConfig') {
      return "Add $prereq->{count} units to garrisons";
   }
   elsif ($t eq 'DefensiveCoveragePrereqConfig') {
      return "Defend $prereq->{percent}% of buildings";
   }
   elsif ($t eq 'HaveLandExpansionsPrereqConfig') {
      return $text || "Expand $prereq->{count} spaces";
   }
   elsif ($t eq 'CompleteMissionPrereqConfig') {
      my $m = BN::Mission->get($prereq->{missionId});
      return 'Complete ' . mission_link($m) if $m;
   }
   elsif ($t eq 'CompleteAnyMissionPrereqConfig'
      || $t eq 'ActiveMissionPrereqConfig')
   {
      if (my $ids = $prereq->{missionIds}) {
         my $what = join(' or ', map { mission_link($_) }
            map { BN::Mission->get($_) } @$ids);
         return "Complete $what" if $what;
      }
   }
   elsif ($t eq 'ZoomCameraPrereqConfig') {
      return $text || 'Zoom the camera';
   }
   return $text || "Other: $t";
}

sub count {
   my ($num) = @_;
   $num = $num->{count} if ref $num;
   return $num && $num > 1 ? " x $num" : '';
}

1 # end BN::Out::Missions
