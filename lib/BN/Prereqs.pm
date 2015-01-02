package BN::Prereqs;
use strict;
use warnings;

my $ran_calc;

sub level {
   my ($obj) = @_;
   _calc_levels() unless $ran_calc;
   return $obj->{_level};
}

sub is_promo {
   my ($obj) = @_;
   _calc_levels() unless $ran_calc;
   return $obj->{_promo} ? 1 : '';
}

sub promo_tag {
   my ($obj) = @_;
   _calc_levels() unless $ran_calc;
   my $p = $obj->{_promo} or return;
   return join '+', sort keys %$p;
}

my %initial_promos = (
   TF2_HEAVYSCOUT_010_DoStuff          => 'tf2_promo_tag',
   p01_BK2RR_060_HelpAdventurer        => 'old_tutorial',
   p01_BUILD_040_CollectSupplyDrops    => 'old_tutorial',
   p01_BUILD_100_TeachCamera           => 'old_tutorial',
   p01_BUILD_280_BuildBunker2          => 'old_tutorial',
   p01_BUILD_510_BuildHospital         => 'old_tutorial',
   p01_HOSP_010_QueueSomething         => 'old_tutorial',
   p01_INTRO_020_OpeningBattle         => 'old_tutorial',
   p01_INTRO_040_BuildShelter          => 'old_tutorial',
   p01_NEWINTRO_120_BuildStoneQuarry   => 'old_tutorial',
   p01_NEWINTRO_140_BuildHospital      => 'old_tutorial',
   p01_RTANK_010_RaiderScouts          => 'old_tutorial',
   p01_RTANK_060_BuildToolShop         => 'old_tutorial',
   p01_ZOEY1_010_BuildHovel            => 'old_tutorial',
);

my %initial_level = (
   p01_LVLUP_010_UnitPromotion1        => 4,
);

sub _calc_levels {
   $ran_calc = 1;
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
         my $id = $obj->tag();
         $obj->{_level} = $initial_level{$id};
         if (my $tag = $initial_promos{$id}) {
            $obj->{_promo}{$tag} = 1;
         }
         _add_prereq($obj, $_) foreach $obj->prereqs();
         push @has_prereqs, $obj if $obj->{z_prereqs};
      }
   }

   foreach my $unit (BN::Unit->all()) {
      $unit->{z_prereqs} = []
         if $unit->side() ne 'Player' && $unit->{z_prereqs};
   }

   my $changed;
   do {
      $changed = 0;
      foreach my $obj (@has_prereqs) {
         PREREQ: foreach my $prereq (@{$obj->{z_prereqs}}) {
            my $type = $prereq->{type};
            my @promo;
            foreach my $id (@{$prereq->{ids}}) {
               my $o = $type->get($id);
               my $p = $o->{_promo} or next PREREQ;
               push @promo, $p;
            }
            my $first = shift @promo or next;
            TAG: foreach my $tag (sort keys %$first) {
               next if $obj->{_promo}{$tag};
               foreach my $p (@promo) {
                  next TAG unless $p->{$tag};
               }
               $obj->{_promo}{$tag} = 1;
               $changed = 1;
            }
         }
      }
   } while $changed;

   foreach my $obj (@has_prereqs) {
      next if $obj->is_promo();
      foreach my $prereq (@{$obj->{z_prereqs}}) {
         my $ids = $prereq->{ids} or next;
         next unless @$ids > 1;
         my $type = $prereq->{type};
         my @new;
         foreach my $id (@$ids) {
            my $o = $type->get($id) or next;
            push @new, $id unless $o->is_promo();
         }
         if (@new != @$ids) {
            $prereq->{old_ids} = $ids;
            $prereq->{ids} = \@new;
         }
      }
   }

   do {
      $changed = 0;
      foreach my $obj (@has_prereqs) {
         foreach my $prereq (@{$obj->{z_prereqs}}) {
            my $level = 999;
            my $type = $prereq->{type};
            foreach my $id (@{$prereq->{ids}}) {
               my $other = $type->get($id) or next;
               my $olevel = $other->{_level} // 0;
               $level = $olevel if $olevel < $level;
            }
            if ($level < 999 && $level > 0 &&
               (!defined($obj->{_level}) || $level > $obj->{_level}))
            {
               $obj->{_level} = $level;
               $changed = 1;
            }
         }
      }
   } while $changed;

   BN::Unit->enemy_levels();
}

sub _add_prereq {
   my ($obj, $prereq) = @_;
   return unless $prereq;
   return if $prereq->{inverse};
   my $t = $prereq->{_t} or return;
   my ($type, $ids, $id);
   if ($t eq 'LevelPrereqConfig') {
      my $level = $prereq->{level} or return;
      $obj->{_level} = $level if $level >= 1;
   }
   elsif ($t eq 'ActiveTagPrereqConfig') {
      my $tags = $prereq->{tags} or return;
      $obj->{_promo}{$_} = 1 foreach @$tags;
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

1 # end BN::Prereqs
