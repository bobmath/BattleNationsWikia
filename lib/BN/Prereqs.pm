package BN::Prereqs;
use strict;
use warnings;

my %init_level = (
   p01_LVLUP_010_UnitPromotion1  => 1,
);

my %init_promo = (
   p01_INTRO_040_BuildShelter    => 'old_missions',
   TF2_HEAVYSCOUT_010_DoStuff    => 'tf2_promo_tag',
);

sub _calc_levels {
   # find prereqs
   my (%prereqs, %marks, @temp_prereqs, @has_prereqs);
   foreach my $class (qw[ BN::Unit BN::Building
      BN::Mission BN::Mission::Completion ])
   {
      foreach my $obj ($class->all()) {
         my $id = $obj->{_tag} // '';
         $obj->{_level} = $init_level{$id};
         if (my $promo = $init_promo{$id}) {
            $obj->{_promo} = { $promo => 1 };
         }
         else {
            $obj->{_promo} = undef;
         }
         my @prereqs;
         foreach my $prereq ($obj->prereqs()) {
            my @pre = _get_prereqs($obj, $prereq) or next;
            push @prereqs, \@pre;
         }
         if (@prereqs) {
            $prereqs{$obj} = \@prereqs;
            $marks{$obj} = 1;
            push @temp_prereqs, $obj;
         }
      }
   }

   # topological sort (speeds up later calculations)
   while (@temp_prereqs) {
      my $obj = pop @temp_prereqs;
      my $mark = $marks{$obj} or next;
      if ($mark == 1) {
         $marks{$obj} = 2;
         push @temp_prereqs, $obj;
         foreach my $grp (@{$prereqs{$obj}}) {
            foreach my $other (@$grp) {
               push @temp_prereqs, $other if ($marks{$obj} // 0) == 1;
            }
         }
      }
      elsif ($mark == 2) {
         $marks{$obj} = 3;
         push @has_prereqs, $obj;
      }
   }
   undef %marks;

   # propagate promo tags
   my $changed;
   do {
      $changed = 0;
      foreach my $obj (@has_prereqs) {
         GROUP: foreach my $group (@{$prereqs{$obj}}) {
            # tag flows in only if all members of group have it
            my @tags;
            foreach my $other (@$group) {
               my $t = $other->{_promo} or next GROUP;
               push @tags, $t;
            }
            my $first = shift @tags or next;
            TAG: foreach my $tag (sort keys %$first) {
               next if $obj->{_promo}{$tag};
               foreach my $t (@tags) {
                  next TAG unless $t->{$tag};
               }
               $obj->{_promo}{$tag} = 1;
               $changed = 1;
            }
         }
      }
   } while $changed;

   # don't propagate promo levels into non-promo stuff
   foreach my $obj (@has_prereqs) {
      next if $obj->is_promo();
      foreach my $group (@{$prereqs{$obj}}) {
         my @new = grep { !$_->is_promo() } @$group;
         $group = \@new if @new;
      }
   }

   # propagate levels
   do {
      $changed = 0;
      foreach my $obj (@has_prereqs) {
         foreach my $group (@{$prereqs{$obj}}) {
            my $level = 99;
            foreach my $other (@$group) {
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

   # calculate full prereqs
   my %full_prereqs;
   foreach my $mis (BN::Mission->all()) {
      $full_prereqs{$mis->completion()} = $full_prereqs{$mis} =
         $mis->{zz_full_prereqs} = { $mis->tag() => 1 };
   }
   do {
      $changed = 0;
      foreach my $obj (@has_prereqs) {
         my $full = $full_prereqs{$obj} ||= { };
         foreach my $group (@{$prereqs{$obj}}) {
            my @tags;
            foreach my $other (@$group) {
               push @tags, $full_prereqs{$other} ||= { };
            }
            my $first = shift @tags or next;
            TAG: foreach my $tag (sort keys %$first) {
               next if $full->{$tag};
               foreach my $t (@tags) {
                  next TAG unless $t->{$tag};
               }
               $full->{$tag} = 1;
               $changed = 1;
            }
         }
      }
   } while $changed;

   BN::Unit->enemy_levels();
}

sub _get_prereqs {
   my ($obj, $prereq) = @_;
   return if !$prereq || $prereq->{inverse};
   my $t = $prereq->{_t} or return;
   if ($t eq 'LevelPrereqConfig') {
      my $level = $prereq->{level} or return;
      return if $level < 1;
      my $max = BN::Level->max() + 10;
      $level = $max if $level > $max;
      $obj->{_level} = $level;
   }
   elsif ($t eq 'ActiveTagPrereqConfig') {
      my $tags = $prereq->{tags} or return;
      $obj->{_promo}{$_} = 1 foreach @$tags;
   }
   elsif ($t eq 'CompleteMissionPrereqConfig') {
      return BN::Mission::Completion->get($prereq->{missionId});
   }
   elsif ($t eq 'CompleteAnyMissionPrereqConfig') {
      my $ids = $prereq->{missionIds} or return;
      return map { BN::Mission::Completion->get($_) } @$ids;
   }
   elsif ($t eq 'ActiveMissionPrereqConfig') {
      my $ids = $prereq->{missionIds} or return;
      return map { BN::Mission->get($_) } @$ids;
   }
   elsif ($t eq 'CreateStructurePrereqConfig'
         || $t eq 'CollectStructurePrereqConfig') {
      return BN::Building->get($prereq->{structureType});
   }
   elsif ($t eq 'HasCompositionPrereqConfig') {
      return BN::Building->get($prereq->{compositionName});
   }
   elsif ($t eq 'HaveAnyOfTheseStructuresPrereqConfig') {
      my $ids = $prereq->{buildings} or return;
      return map { BN::Building->get($_) } @$ids;
   }
   elsif ($t eq 'BuildingLevelPrereqConfig') {
      my $ids = $prereq->{compositionIds} or return;
      return map { BN::Building->get($_) } @$ids;
   }
   elsif ($t eq 'HaveOneOfTheseStructuresPrereqConfig') {
      my $counts = $prereq->{buildingCounts} or return;
      return map { BN::Building->get($_) } sort keys %$counts;
   }
   elsif ($t eq 'CollectProjectPrereqConfig'
         || $t eq 'StartProjectPrereqConfig') {
      return BN::Unit->get($prereq->{projectId});
   }
   return;
}

sub level {
   my ($obj) = @_;
   _calc_levels() unless exists $obj->{_level};
   return $obj->{_level};
}

sub is_promo {
   my ($obj) = @_;
   _calc_levels() unless exists $obj->{_promo};
   return $obj->{_promo} ? 1 : undef;
}

sub promo_tags {
   my ($obj) = @_;
   _calc_levels() unless exists $obj->{_promo};
   my $promo = $obj->{_promo} or return;
   return join '+', sort keys %$promo;
}

1 # end BN::Prereqs
