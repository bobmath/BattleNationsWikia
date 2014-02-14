package BN::Prereqs;
use strict;
use warnings;

sub calc_levels {
   my @has_prereqs;
   foreach my $obj (BN::Unit->all(), BN::Building->all(), BN::Mission->all()) {
      $obj->{_level} = undef;
      add_prereq($obj, $_) foreach $obj->prereqs();
      push @has_prereqs, $obj if $obj->{z_prereqs};
   }

   if (my $mis = BN::Mission->get('p01_INTRO_040_BuildShelter')) {
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
               my $olevel = $other->{_level};
               $level = $olevel if defined($olevel) && $olevel < $level;
            }
            if ($level < 99 &&
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
      $level = 66 if $level > 66;
      $obj->{_level} = $level;
   }
   elsif ($t eq 'CompleteMissionPrereqConfig') {
      $type = 'Mission';
      $id = $prereq->{missionId};
   }
   elsif ($t eq 'CompleteAnyMissionPrereqConfig'
      || $t eq 'ActiveMissionPrereqConfig')
   {
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
