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
      my $max = BN::Level->max() + 10;
      $level = $max if $level > $max;
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

1 # end BN::Prereqs
