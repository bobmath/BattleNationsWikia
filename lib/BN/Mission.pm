package BN::Mission;
use strict;
use warnings;

my $missions;
my $json_file = 'Missions.json';

sub all {
   my ($class) = @_;
   $missions ||= BN::File->json($json_file);
   return map { $class->get($_) } sort keys %$missions;
}

my %name = (
   p02_SWLG_010_HiddenEncounter1    => 'Mystery Troops 1',
   p02_SWLG_020_HiddenEncounter2    => 'Mystery Troops 2',
   p02_SWLG_030_HiddenEncounter3    => 'Mystery Troops 3',
   p03_PLASMA_020_RebelFight        => 'Defense is the Best (Insert Cliche Here)',
);

sub get {
   my ($class, $key) = @_;
   return unless $key;
   $missions ||= BN::File->json($json_file);
   my $mis = $missions->{$key} or return;
   if (ref($mis) eq 'HASH') {
      bless $mis, $class;
      $mis->{_tag} = $key;
      my $name = $name{$key} || BN::Text->get($mis->{title}) || $key;
      $name .= ' (Hidden)' if $mis->{hideIcon} && $name !~ /hidden/i;
      $name =~ s/\x{2026}/.../g;
      $mis->{_name} = $name;
   }
   return $mis;
}

sub get_by_name {
   my ($class, $key) = @_;
   return unless defined $key;
   foreach my $mis ($class->all()) {
      return $mis if $mis->{_name} eq $key;
   }
   return;
}

BN->simple_accessor('name');
BN->simple_accessor('tag');
BN->simple_accessor('hidden', 'hideIcon');

my %promo_wikipage = (
   old_tutorial   => 'Old Tutorial',
   promo_xmas2014 => 'Twelve Days of Christmas',
   tf2_promo_tag  => 'Team Fortress 2 missions',
);

sub wikipage {
   my ($mis) = @_;
   if (my $tag = $mis->promo_tag()) {
      return $promo_wikipage{$tag} || 'Other Promos';
   }
   if (my $level = $mis->level()) {
      my $lo = int(($level - 1) / 5) * 5 + 1;
      my $hi = $lo + 4;
      my $max = BN::Level->max();
      $hi = $max if $hi > $max && $lo < $max;
      return "Level $lo-$hi missions";
   }
   return 'Missions';
}

sub wikilink {
   my ($mis, $text) = @_;
   $text //= $mis->{_name};
   my $link = '[[' . $mis->wikipage() . '#' . $mis->{_name};
   $link .= '|' . $text if length($text);
   $link .= ']]';
   return $link;
}

sub level {
   my ($mis) = @_;
   return $mis->{_level} if exists $mis->{_level};
   BN::Prereqs->calc_levels();
   return $mis->{_level};
}

sub prereqs {
   my ($mis) = @_;
   my @prereqs;
   foreach my $field (qw( startRules persistenceRules )) {
      my $rules = $mis->{$field} or next;
      foreach my $key (sort keys %$rules) {
         my $rule = $rules->{$key} or next;
         my $prereq = $rule->{prereq} or next;
         push @prereqs, $prereq;
      }
   }
   return @prereqs;
}

BN->accessor(rewards => sub {
   my ($mis) = @_;
   return BN->flatten_amount(delete($mis->{rewards}));
});

BN->list_accessor(objectives => sub {
   my ($mis) = @_;
   my $objectives = delete $mis->{objectives} or return;
   my @obj;
   foreach my $key (sort keys %$objectives) {
      push @obj, BN::Mission::Objective->new($objectives->{$key}, $key);
   }
   return @obj;
});

sub unlocks_buildings {
   my ($mis) = @_;
   if (!exists $mis->{_unlocks_buildings}) {
      $_->{_unlocks_buildings} = undef foreach BN::Mission->all();
      foreach my $bld (BN::Building->all()) {
         foreach my $id ($bld->mission_reqs()) {
            my $m = BN::Mission->get($id) or next;
            push @{$m->{_unlocks_buildings}}, $bld->tag();
         }
      }
   }
   return unless $mis->{_unlocks_buildings};
   return map { BN::Building->get($_) } @{$mis->{_unlocks_buildings}};
}

sub unlocks_units {
   my ($mis) = @_;
   if (!exists $mis->{_unlocks_units}) {
      $_->{_unlocks_units} = undef foreach BN::Mission->all();
      foreach my $unit (BN::Unit->all()) {
         foreach my $id ($unit->mission_reqs()) {
            my $m = BN::Mission->get($id) or next;
            push @{$m->{_unlocks_units}}, $unit->tag();
         }
      }
   }
   return unless $mis->{_unlocks_units};
   return map { BN::Unit->get($_) } @{$mis->{_unlocks_units}};
}

sub start_script {
   my ($mis) = @_;
   my $tag = 'zz1_start_script';
   return $mis->{$tag} if exists $mis->{$tag};
   return $mis->{$tag} = get_script($mis->{startScript});
}

sub description_script {
   my ($mis) = @_;
   my $tag = 'zz2_description_script';
   return $mis->{$tag} if exists $mis->{$tag};
   return $mis->{$tag} = get_script($mis->{description});
}

sub finish_script {
   my ($mis) = @_;
   my $tag = 'zz3_finish_script';
   return $mis->{$tag} if exists $mis->{$tag};
   return $mis->{$tag} = get_script($mis->{finishScript});
}

sub reward_script {
   my ($mis) = @_;
   my $tag = 'zz4_reward_script';
   return $mis->{$tag} if exists $mis->{$tag};
   return $mis->{$tag} = get_script($mis->{completeScript});
}

my $dialogs;
sub get_script {
   my ($script) = @_;
   $script = $script->{scriptId} if ref($script);
   return undef unless $script;
   $dialogs ||= BN::File->json('Dialogs.json');
   my $data = $dialogs->{$script} or return undef;
   foreach my $lines (@$data) {
      my $text = $lines->{text} or next;
      foreach my $line (@$text) {
         $line->{_title} = BN::Text->get($line->{title}) if $line->{title};
         $line->{_body} = BN::Text->get($line->{body});
      }
   }
   return $data;
}

BN->list_accessor(encounter_ids => sub {
   my ($mis) = @_;
   my %ids;

   foreach my $objective ($mis->objectives()) {
      my $prereq = $objective->{prereq} or next;
      my $t = $prereq->{_t} or next;
      if ($t eq 'DefeatEncounterPrereqConfig') {
         my $id = $prereq->{encounterId} or next;
         $ids{$id} = 1;
      }
      elsif ($t eq 'DefeatEncounterSetPrereqConfig') {
         my $ids = $prereq->{encounterIds} or next;
         $ids{$_} = 1 foreach @$ids;
      }
   }

   if (my $effects = $mis->{serverEffects}) {
      foreach my $effect (@$effects) {
         my $elist = $effect->{encounters} or next;
         foreach my $enc (@$elist) {
            my $id = $enc->{encounterId} or next;
            $ids{$id} = 1;
         }
      }
   }

   return sort keys %ids;
});

sub encounters {
   my ($mis) = @_;
   return map { BN::Encounter->get($_) } $mis->encounter_ids();
}

my $ran_promo;

sub is_promo {
   my ($mis) = @_;
   _calc_promo() unless $ran_promo;
   return $mis->{_promo} ? 1 : '';
}

sub promo_tag {
   my ($mis) = @_;
   _calc_promo() unless $ran_promo;
   my $p = $mis->{_promo} or return;
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

sub _calc_promo {
   $ran_promo = 1;
   my @missions = BN::Mission->all();
   foreach my $mis (@missions) {
      if (my $tag = $initial_promos{$mis->{_tag}}) {
         $mis->{_promo}{$tag} = 1;
      }
      foreach my $prereq ($mis->prereqs()) {
         next if $prereq->{inverse};
         my $t = $prereq->{_t} or next;
         if ($t eq 'ActiveTagPrereqConfig') {
            my $tags = $prereq->{tags} or next;
            $mis->{_promo}{$_} = 1 foreach @$tags;
         }
      }
   }
   my $changed = 1;
   while ($changed) {
      $changed = 0;
      foreach my $mis (@missions) {
         PREREQ: foreach my $prereq ($mis->prereqs()) {
            next if $prereq->{inverse};
            my $t = $prereq->{_t} or next;
            if ($t eq 'CompleteMissionPrereqConfig') {
               my $m = BN::Mission->get($prereq->{missionId});
               my $p = $m->{_promo} or next;
               foreach my $k (sort keys %$p) {
                  next if $mis->{_promo}{$k};
                  $mis->{_promo}{$k} = 1;
                  $changed = 1;
               }
            }
            elsif ($t eq 'CompleteAnyMissionPrereqConfig') {
               my $ids = $prereq->{missionIds} or next;
               my @promos;
               foreach my $id (@$ids) {
                  my $m = BN::Mission->get($id) or next;
                  my $promo = $m->{_promo} or next PREREQ;
                  push @promos, $promo;
               }
               my $first = shift @promos or next;
               TAG: foreach my $tag (sort keys %$first) {
                  next if $mis->{_promo}{$tag};
                  foreach my $tags (@promos) {
                     next TAG unless $tags->{$tag};
                  }
                  $mis->{_promo}{$tag} = 1;
                  $changed = 1;
               }
            }
         }
      }
   }
}

sub full_prereqs {
   my ($mis) = @_;
   _calc_prereqs() unless exists $mis->{zz_full_prereqs};
   return $mis->{zz_full_prereqs};
}

sub _calc_prereqs {
   my @missions = BN::Mission->all();
   foreach my $mis (@missions) {
      $mis->{zz_full_prereqs} = { $mis->{_tag} => 1 };
   }
   my $changed = 1;
   while ($changed) {
      $changed = 0;
      foreach my $mis (@missions) {
         my $full = $mis->{zz_full_prereqs} or die;
         foreach my $prereq ($mis->prereqs(), $mis->completion()->prereqs()) {
            next if $prereq->{inverse};
            my $t = $prereq->{_t} or next;
            if ($t eq 'CompleteMissionPrereqConfig') {
               my $m = BN::Mission->get($prereq->{missionId}) or next;
               foreach my $id (sort keys %{$m->{zz_full_prereqs}}) {
                  next if $full->{$id};
                  $full->{$id} = 1;
                  $changed = 1;
               }
            }
            elsif ($t eq 'CompleteAnyMissionPrereqConfig'
               || $t eq 'ActiveMissionPrereqConfig')
            {
               my $ids = $prereq->{missionIds} or next;
               my @full;
               foreach my $id (@$ids) {
                  my $m = BN::Mission->get($id) or next;
                  next if $m->is_promo() && !$mis->is_promo();
                  push @full, $m->{zz_full_prereqs};
               }
               my $first = shift @full or next;
               TAG: foreach my $tag (sort keys %$first) {
                  next if $full->{$tag};
                  foreach my $tags (@full) {
                     next TAG unless $tags->{$tag};
                  }
                  $full->{$tag} = 1;
                  $changed = 1;
               }
            }
         }
      }
   }
}

BN->list_accessor(min_prereqs => sub {
   my ($mis) = @_;
   my @prereqs;

   foreach my $prereq ($mis->prereqs(), $mis->completion()->prereqs()) {
      my $t = $prereq->{_t} or next;
      next if $prereq->{inverse};
      if ($t eq 'CompleteMissionPrereqConfig') {
         my $id = $prereq->{missionId};
         push @prereqs, $id if $id;
      }
      elsif ($t eq 'CompleteAnyMissionPrereqConfig'
         || $t eq 'ActiveMissionPrereqConfig')
      {
         my $ids = $prereq->{missionIds} or next;
         push @prereqs, @$ids if $ids;
      }
   }

   if (!$mis->is_promo()) {
      @prereqs = map { $_->tag() } grep { !$_->is_promo() }
         map { BN::Mission->get($_) } @prereqs;
   }

   my @filtered;
   FILTER: while (@prereqs) {
      my $id = shift @prereqs;
      my $m = BN::Mission->get($id) or next;
      foreach my $fid (@filtered, @prereqs) {
         my $f = BN::Mission->get($fid) or next;
         my $p = $f->full_prereqs() or next;
         next FILTER if $p->{$id};
      }
      push @filtered, $id;
   }
   return @filtered;
});

sub followups {
   my ($mis) = @_;
   if (!$mis->{z_followups}) {
      $_->{z_followups} = [] foreach BN::Mission->all();
      foreach my $m (BN::Mission->all()) {
         foreach my $id ($m->min_prereqs()) {
            my $p = BN::Mission->get($id) or next;
            next if !$p->is_promo() && $m->is_promo();
            push @{$p->{z_followups}}, $m->tag();
         }
      }
   }
   return @{$mis->{z_followups}};
}

sub completion {
   my ($mis) = @_;
   return $mis->{z_completion} ||= BN::Mission::Completion->new($mis->{_tag});
}

package BN::Mission::Completion;

sub all {
   return map { $_->completion() } BN::Mission->all();
}

sub get {
   my ($class, $key) = @_;
   my $mis = BN::Mission->get($key) or return;
   return $mis->completion();
}

sub new {
   my ($class, $id) = @_;
   return bless {
      _parent => $id,
      z_prereqs => [{ type => 'BN::Mission', ids => [$id] }],
   }, $class;
}

sub level {
   my ($self) = @_;
   return $self->{_level} if exists $self->{_level};
   BN::Prereqs->calc_levels();
   return $self->{_level};
}

sub prereqs {
   my ($self) = @_;
   my $parent = BN::Mission->get($self->{_parent}) or return;
   my @prereqs;
   foreach my $objective ($parent->objectives()) {
      my $prereq = $objective->{prereq} or next;
      push @prereqs, $prereq;
   }
   return @prereqs;
}

package BN::Mission::Objective;

sub new {
   my ($class, $obj, $num) = @_;
   return unless $obj;
   $obj->{_num} = $num;
   bless $obj, $class;
   $obj->decorate();
   return $obj;
}

sub decorate {
   my ($obj) = @_;
   $obj->{_link} = '';
   my $prereq = $obj->{prereq} // {};
   $obj->{_text} = BN::Text->get($prereq->{objectiveText});
   my $t = $prereq->{_t} // '';
   if ($t eq 'LevelPrereqConfig') {
      my $level = $prereq->{level} || 1;
      $obj->{_text} //= "Reach level $level";
      $obj->{_link} = "Levels#$level";
   }
   elsif ($t eq 'DefeatEncounterPrereqConfig') {
      if (my $enc = BN::Encounter->get($prereq->{encounterId})) {
         $obj->{_text} //= 'Defeat ' . $enc->name();
         $obj->{icon} //= $enc->icon();
      }
      else {
         $obj->{_text} //= 'Defeat encounter';
      }
   }
   elsif ($t eq 'DefeatEncounterSetPrereqConfig') {
      my $who;
      if (my $ids = $prereq->{encounterIds}) {
         foreach my $id (@$ids) {
            my $enc = BN::Encounter->get($id) or next;
            $who //= $enc->name();
            $obj->{icon} //= $enc->icon();
         }
      }
      $obj->{_text} //= 'Defeat ' . ($who // 'encounter');
   }
   elsif ($t eq 'DefeatOccupationPrereqConfig') {
      $obj->{_text} //= 'Defeat occupation';
   }
   elsif ($t eq 'FinishBattlePrereqConfig') {
      $obj->{_text} //= 'Finish battle';
   }
   elsif ($t eq 'EnterStatePrereqConfig') {
      my $where = $prereq->{state} // '';
      if ($where eq 'MyLand') {
         $obj->{_text} //= 'Go Home';
         $obj->{_link} = 'Outpost';
         $obj->{icon} //= 'Home.png';
      }
      elsif ($where eq 'WorldMap') {
         $obj->{_text} //= 'Go to the World Map';
         $obj->{_link} = 'Northern Frontier';
         $obj->{icon} //= 'Mapicon.png';
      }
   }
   elsif ($t eq 'CreateStructurePrereqConfig') {
      if (my $b = BN::Building->get($prereq->{structureType})) {
         $obj->{_text} //= 'Build ' . $b->name();
         $obj->{_link} = $b->name();
         $obj->{icon} //= $b->icon();
      }
   }
   elsif ($t eq 'HasCompositionPrereqConfig') {
      if (my $b = BN::Building->get($prereq->{compositionName})) {
         $obj->{_text} //= 'Have ' . $b->name() . count($prereq);
         $obj->{_link} = $b->name();
         $obj->{icon} //= $b->icon();
      }
   }
   elsif ($t eq 'HaveAnyOfTheseStructuresPrereqConfig') {
      if (my $ids = $prereq->{buildings}) {
         my @names;
         foreach my $id (@$ids) {
            my $b = BN::Building->get($id) or next;
            push @names, $b->name();
            $obj->{_link} ||= $b->name();
            $obj->{icon} ||= $b->icon();
         }
         $obj->{_text} ||= 'Have ' . join(' or ', @names) if @names;
      }
   }
   elsif ($t eq 'BuildingLevelPrereqConfig') {
      if (my $ids = $prereq->{compositionIds}) {
         my @names;
         foreach my $id (@$ids) {
            my $b = BN::Building->get($id) or next;
            push @names, $b->name();
            $obj->{_link} ||= $b->name();
            $obj->{icon} ||= $b->icon();
         }
         $obj->{_text} //= 'Upgrade ' . join(' or ', @names)
            . ' to level ' . ($prereq->{level} // 1) if @names;
      }
   }
   elsif ($t eq 'CompleteMissionPrereqConfig') {
      if (my $m = BN::Mission->get($prereq->{missionId})) {
         $obj->{_text} //= 'Complete mission ' . $m->name();
      }
   }
   elsif ($t eq 'ActiveMissionPrereqConfig') {
      if (my $ids = $prereq->{missionIds}) {
         my @names;
         foreach my $id (@$ids) {
            my $m = BN::Mission->get($id) or next;
            push @names, $m->name();
         }
         $obj->{_text} //= 'Start mission ' . join(' or ', @names) if @names;
      }
   }
   elsif ($t eq 'StartJobPrereqConfig' || $t eq 'CollectJobPrereqConfig') {
      if (my $job = BN::Job->get($prereq->{jobId})) {
         my $verb = 'Make';
         if (my ($bldid) = $job->buildings()) {
            my $bld = BN::Building->get($bldid);
            $verb = 'Grow' if ($bld->gets_bonus() // '') =~ /Agricultur/;
            $obj->{_link} = $bld->name() . '#Goods';
            $obj->{_timetag} = $bldid;
         }
         $obj->{_text} //= $verb . ' ' . $job->name();
         if ((my $count = $prereq->{count} || 1) > 1) {
            $obj->{_text} .= " x $count" if
               index($obj->{_text}, $count) < 0;
         }
         $obj->{icon} //= $job->icon();
         if ($t eq 'CollectJobPrereqConfig' && (my $cost = $job->cost())) {
            my $num = $prereq->{count} || 1;
            my %cost;
            while (my ($k,$v) = each %$cost) {
               $cost{$k} += $v * $num;
            }
            $obj->{_time} = delete $cost{time};
            $obj->{_cost} = \%cost;
         }
      }
   }
   elsif ($t eq 'AttackNPCBuildingPrereqConfig') {
      if (my $b = BN::Building->get($prereq->{compositionName})) {
         $obj->{_text} //= 'Attack ' . $b->name();
         $obj->{_link} = $b->name();
         $obj->{icon} //= $b->icon();
      }
   }
   elsif ($t eq 'StartProjectPrereqConfig'
      || $t eq 'CollectProjectPrereqConfig')
   {
      if (my $u = BN::Unit->get($prereq->{projectId})) {
         $obj->{_text} //= 'Train ' . $u->name();
         $obj->{_link} = $u->wiki_page();
         $obj->{icon} //= $u->icon();
      }
   }
   elsif ($t eq 'CollectTaxesPrereqConfig') {
      $obj->{_text} //= 'Collect taxes' . count($prereq);
   }
   elsif ($t eq 'EnterOpponentLandPrereqConfig') {
      if (my $map = BN::Map->get($prereq->{opponentId})) {
         $obj->{_text} //= 'Go to ' . $map->name();
         $obj->{_link} = $map->name();
         $obj->{icon} //= 'Mapicon.png';
      }
   }
   elsif ($t eq 'PanCameraPrereqConfig') {
      $obj->{_text} //= 'Pan camera';
   }
   elsif ($t eq 'ZoomCameraPrereqConfig') {
      $obj->{_text} //= 'Zoom camera';
   }
   $obj->{_text} //= '???';
}

BN->simple_accessor('text');
BN->simple_accessor('link');
BN->simple_accessor('cost');
BN->simple_accessor('time');
BN->simple_accessor('timetag');
BN->simple_accessor('icon', 'icon');

sub count {
   my ($num) = @_;
   $num = $num->{count} if ref $num;
   return $num && $num > 1 ? " x $num" : '';
}

1 # end BN::Mission::Objective
