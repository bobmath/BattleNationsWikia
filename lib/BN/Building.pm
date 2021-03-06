package BN::Building;
use strict;
use warnings;
use POSIX qw( ceil );
@BN::Building::ISA = qw( BN::Prereqs );

my $buildings;
my $json_file = 'Compositions.json';

sub all {
   my ($class) = @_;
   $buildings ||= BN::File->json($json_file);
   return map { $class->get($_) } sort keys %$buildings;
}

sub get {
   my ($class, $key) = @_;
   return unless $key;
   $buildings ||= BN::File->json($json_file);
   my $build = $buildings->{$key} or return;
   if (ref($build) eq 'HASH') {
      bless $build, $class;
      $build->{_tag} = $key;
      if (my $configs = delete $build->{componentConfigs}) {
         while (my ($k,$v) = each %$configs) {
            $build->{$k} = $v;
         }
      }
      if (my $struct = $build->{StructureMenu}) {
         $build->{_name} = BN::Text->get($struct->{name});
      }
      $build->{_name} //= $key;
   }
   return $build;
}

sub get_by_name {
   my ($class, $name) = @_;
   return unless defined $name;
   foreach my $build ($class->all()) {
      return $build if $build->name() eq $name;
   }
   return;
}

BN->simple_accessor('tag');
BN->simple_accessor('name');

sub wikilink {
   my ($build) = @_;
   return "[[$build->{_name}]]";
}

sub icon {
   my ($build) = @_;
   my $structure = $build->{StructureMenu} or return undef;
   return $structure->{icon};
}

sub description {
   my ($build) = @_;
   my $structure = $build->{StructureMenu} or return undef;
   return BN::Text->get($structure->{description});
}

sub units {
   my ($build) = @_;
   my $projects = $build->{ProjectList} or return;
   my $jobs = $projects->{jobs} or return;
   return map { BN::Unit->get($_) } @$jobs;
}

sub prereqs {
   my ($build) = @_;
   my $structure = $build->{StructureMenu} or return;
   my $prereqs = $structure->{prereq} or return;
   return map { $prereqs->{$_} } sort keys %$prereqs;
}

my %build_cats = (
   bmCat_houses => 'Housing',
   bmCat_shops  => 'Shops',
   bmCat_military => 'Military',
   bmCat_resources => 'Resources',
   bmCat_decorations => 'Decorations',
);

sub build_menu {
   my ($build) = @_;
   return $build->{_build_menu} if exists $build->{_build_menu};

   my $buildable = BN::File->json('StructureMenu.json');

   foreach my $b (BN::Building->all()) {
      $b->{_build_menu} = undef;
   }

   foreach my $group (@$buildable) {
      my $cat = $build_cats{$group->{title}} or next;
      foreach my $tag (@{$group->{options}}) {
         my $build = BN::Building->get($tag) or next;
         $build->{_build_menu} = $cat;
      }
   }

   return $build->{_build_menu};
}

BN->accessor(build_type => sub {
   my ($build) = @_;
   return 'Healing' if $build->{Healing};
   return 'Defense' if $build->{DefenseStructure} || $build->{Garrison};
   return 'Bonus Decor' if $build->{RadialMod};
   my $type = $build->build_menu() or return;
   $type =~ s/s$//;
   return $type;
});

BN->accessor(population => sub {
   my ($build) = @_;
   if (my $pop = $build->{PopulationCapacity}) {
      return '+' . $pop->{contribution};
   }
   elsif (my $work = $build->{RequireWorkers}) {
      return '-' . $work->{workers};
   }
   return;
});

BN->accessor(population_inactive => sub {
   my ($build) = @_;
   my $work = $build->{RequireWorkers} or return;
   return unless $work->{canToggle};
   return '-' . $work->{minWorkers};
});

sub defense {
   my ($build) = @_;
   my $defense = $build->{DefenseStructure} or return;
   return $defense->{unitId};
}

sub defense_radius {
   my ($build) = @_;
   my $defense = $build->{DefenseStructure} || $build->{Garrison} or return;
   return $defense->{radius};
}

sub repair_time {
   my ($build) = @_;
   my $defense = $build->{DefenseStructure} or return;
   return BN->format_time($defense->{repairTime});
}

sub garrison_size {
   my ($build) = @_;
   my $garrison = $build->{Garrison} or return;
   return $garrison->{unitCount};
}

sub size {
   my ($build) = @_;
   my $place = $build->{Placeable} or return;
   return "$place->{width} x $place->{height}";
}

BN->accessor(cost => sub {
   my ($build) = @_;
   my $structure = $build->{StructureMenu};
   my $construct = $build->{Construction};
   return BN->flatten_amount(delete($structure->{cost}),
      delete($construct->{buildTime}));
});

my $reward_tables;
BN->accessor(assist_reward => sub {
   my ($build) = @_;
   my $assist = $build->{Assistance} or return;
   my $rewards = delete $assist->{rewards} or return;
   if (my $table = BN::Reward->get($assist->{rewardTable})) {
      delete $table->{merits};
      $rewards->{table} = $table if %$table;
   }
   return BN->flatten_amount($rewards);
});

BN->accessor(max_assists => sub {
   my ($build) = @_;
   my $assist = $build->{Assistance} or return;
   return $assist->{interactionLimit};
});

BN->accessor(assist_bonus => sub {
   my ($build) = @_;
   my $assist = $build->{Assistance} or return;
   my $action = $assist->{acceptanceAction} or return;
   my $time = $action->{minutesAdded} or return;
   return "{{Time|+${time}m}}";
});

BN->accessor(raid_reward => sub {
   my ($build) = @_;
   my $battle = $build->{BattleReward} or return;
   return BN->flatten_amount(delete($battle->{rewards}));
});

BN->accessor(occupy_reward => sub {
   my ($build) = @_;
   my $raid = $build->raid_reward() or return;
   my %occupy;
   while (my ($key, $val) = each %$raid) {
      $occupy{$key} = ceil($val * 3.8);
   }
   return \%occupy;
});

BN->accessor(sell_price => sub {
   my ($build) = @_;
   my $sell = $build->{Sellable} or return;
   return BN->flatten_amount(delete($sell->{amount}));
});

BN->list_accessor(levels => sub {
   my ($build) = @_;
   my $upgrade = $build->{BuildingUpgrade} or return;
   my $levels = delete($upgrade->{levels}) or return;
   my $n;
   return map { BN::Building::Level->new($_, ++$n) } @$levels;
});

my %bonus_from = (
   Agricultural   => '[[:Category:Bonus to Agriculture|Agriculture]]',
   Houses         => '[[:Category:Bonus to Houses|Houses]]',
   Ranches        => '[[:Category:Bonus to Ranches|Ranches]]',
   Shops          => '[[:Category:Bonus to Shops|Shops]]',
);
BN->accessor(gets_bonus => sub {
   my ($build) = @_;
   return if $build->{ResourceProducer};
   my $buff = $build->{RadialModBuffable} or return;
   my $tags = $buff->{tags} or return;
   my @tags = grep { $_ ne 'all' } @$tags or return;
   return join ', ', map { $bonus_from{$_} || $_ } sort @tags;
});

BN->accessor(gives_bonus => sub {
   my ($build) = @_;
   my $bonus = $build->{RadialMod} or return;
   my $stats = BN->flatten_amount($bonus->{stats}) or return;
   if ($stats->{gold} && $stats->{XP} && $stats->{gold} == $stats->{XP}) {
      $stats->{goldXP} = delete $stats->{gold};
      delete $stats->{XP};
   }
   if (my $rsrc = delete $stats->{resources}) {
      my $type = $build->gives_bonus_to() // '';
      if    ($type =~ /Stone/)   { $stats->{stone} = $rsrc }
      elsif ($type =~ /Logging/) { $stats->{wood}  = $rsrc }
      elsif ($type =~ /Iron/)    { $stats->{iron}  = $rsrc }
      elsif ($type =~ /Oil/)     { $stats->{oil}   = $rsrc }
      elsif ($type =~ /Coal/)    { $stats->{coal}  = $rsrc }
   }
   my $fmt = '';
   my $prev_color = '';
   foreach my $key (BN->sort_amount(keys %$stats)) {
      my $val = $stats->{$key} or next;
      my $color = $val > 0 ? 'green' : 'red';
      if ($prev_color eq $color) {
         $fmt .= ' ';
      }
      else {
         $fmt .= '</span> ' if $fmt;
         $fmt .= qq{<span style="color:$color;">};
         $prev_color = $color;
      }
      $fmt .= BN->resource_template($key, sprintf("%+d%%", $val));
   }
   return unless $fmt;
   return $fmt . '</span>';
});

my %bonus_to = (
   'Agricultural'    => '[[:Category:Agriculture|Agriculture]]',
   'Coal Mines'      => '[[Coal Mine]]s<br>[[Adv. Coal Mine]]s',
   'Houses'          => '[[:Category:Housing|Houses]]',
   'Iron Mines'      => '[[Iron Mine]]s<br>[[Adv. Iron Mine]]s',
   'Logging Camps'   => '[[Logging Camp]]s<br>[[Adv. Logging Camp]]s',
   'Oil Pumps'       => '[[Oil Pump]]s<br>[[Adv. Oil Pump]]s',
   'Ranches'         => '[[:Category:Ranches|Ranches]]',
   'Shops'           => '[[:Category:Shop|Shops]]',
   'Stone Quarries'  => '[[Stone Quarry|Stone Quarries]]<br>[[Adv. Stone Quarry|Adv. Stone Quarries]]',
);
BN->accessor(gives_bonus_to => sub {
   my ($build) = @_;
   my $bonus = $build->{RadialMod} or return;
   my $tags = $bonus->{tags} or return;
   return join '<br>', map { $bonus_to{$_} || $_ } sort @$tags;
});

sub bonus_radius {
   my ($build) = @_;
   my $bonus = $build->{RadialMod} or return;
   return $bonus->{radius};
}

my $bonus_cats;

sub bonus_stack {
   my ($build) = @_;
   my $bonus = $build->{RadialMod} or return;
   if (my $max = $bonus->{maxModStack}) {
      return $max;
   }
   if (my $cat = $bonus->{modCategory}) {
      $bonus_cats ||= BN::File->json('RadialMod.json');
      my $lim = $bonus_cats->{categories}{$cat} or return;
      $cat .= 's' if $lim > 1;
      return "$lim $cat";
   }
   return;
}

BN->accessor(unique => sub {
   my ($build) = @_;
   foreach my $prereq ($build->prereqs()) {
      my $t = $prereq->{_t} or next;
      return 1 if $t eq 'SingleEntityPrereqConfig';
   }
   return;
});

BN->list_accessor(mission_reqs => sub {
   my ($build) = @_;
   my @missions;
   foreach my $prereq ($build->prereqs()) {
      my $t = $prereq->{_t} or next;
      if ($t eq 'CompleteMissionPrereqConfig') {
         my $id = $prereq->{missionId} or next;
         push @missions, $id;
      }
      elsif ($t eq 'CompleteAnyMissionPrereqConfig') {
         my $ids = $prereq->{missionIds} or next;
         push @missions, @$ids;
      }
   }
   return @missions;
});

BN->accessor(taxes => sub {
   my ($build) = @_;
   my $taxes = $build->{Taxes} or return;
   return BN->flatten_amount(delete($taxes->{rewards}),
      (delete($taxes->{paymentInterval})||0) * 60);
});

my %demand_map = (
   Spices   => 'Spice',
   Defense  => 'Security',
);
BN->accessor(demand_cat => sub {
   my ($build) = @_;
   my %cats;
   foreach my $job ($build->jobs()) {
      my $cat = $job->demand_cat();
      $cats{$cat} = 1 if $cat;
   }
   return unless %cats;
   return join ' ', map { '{{' . ($demand_map{$_} || $_) . '}}' }
      sort keys %cats;
});

sub resource_rate {
   my ($build) = @_;
   my $resource = $build->{ResourceProducer} or return;
   return $resource->{outputRate};
}

sub resource_type {
   my ($build) = @_;
   if (my $resource = $build->{ResourceProducer}) {
      return $resource->{outputType};
   }
   elsif (my $type = $build->output_type()) {
      return $build->mill_output() if $type eq 'millOutput';
   }
   return;
}

sub input_type {
   my ($build) = @_;
   my $upgrade = $build->{BuildingUpgrade} or return;
   return $upgrade->{inputLabel};
}

sub output_type {
   my ($build) = @_;
   my $upgrade = $build->{BuildingUpgrade} or return;
   return $upgrade->{outputLabel};
}

sub jobs {
   my ($build) = @_;
   $build->get_jobs() unless exists $build->{z_jobs};
   return unless $build->{z_jobs};
   return @{$build->{z_jobs}};
}

sub quest_jobs {
   my ($build) = @_;
   $build->get_jobs() unless exists $build->{z_quest_jobs};
   return unless $build->{z_quest_jobs};
   return @{$build->{z_quest_jobs}};
}

sub get_jobs {
   my ($build) = @_;
   $build->{z_jobs} = $build->{z_quest_jobs} = undef;
   my $joblist = $build->{JobList} or return;
   my $jobs = delete($joblist->{jobs}) or return;
   foreach my $id (@$jobs) {
      my $job = BN::Job->get($id) or next;
      my $field = $job->has_mission() ? 'z_quest_jobs' : 'z_jobs';
      push @{$build->{$field}}, $job;
   }
}

BN->list_accessor(mill_input => sub {
   my ($build) = @_;
   my %in;
   foreach my $job ($build->jobs()) {
      my $cost = $job->cost() or next;
      $in{$_} = 1 foreach keys %$cost;
   }
   delete $in{time};
   return reverse sort keys %in;
});

BN->accessor(mill_output => sub {
   my ($build) = @_;
   my %out;
   foreach my $job ($build->jobs()) {
      my $rewards = $job->rewards() or next;
      $out{$_} = 1 foreach keys %$rewards;
   }
   delete $out{XP};
   return unless %out;
   die 'too many outputs' if keys(%out) > 1;
   my ($out) = keys %out;
   return $out;
});

BN->accessor(mill_rate => sub {
   my ($build) = @_;
   my @jobs = $build->jobs() or return;
   my $cost = $jobs[-1]->cost() or return;
   my $time = $cost->{time} or return;
   my $rewards = $jobs[-1]->rewards() or return;
   die 'unexpected mill rewards' unless keys(%$rewards) == 1;
   my ($out) = values %$rewards;
   return $out * 60*60*12 / $time;
});

sub animation {
   my ($build, $which) = @_;
   my $anim = $build->{Animation} or return;
   $anim = $anim->{animations} or return;
   return $anim->{$which || 'Default'} || $anim->{Default};
}

sub map_link {
   my ($build) = @_;
   my $map = $build->{WorldMapObject} or return;
   return $map->{npcId};
}

package BN::Building::Level;

sub new {
   my ($class, $level, $num) = @_;
   die unless ref($level) eq 'HASH';
   bless $level, $class;
   $level->{_level} = $num;
   return $level;
}

BN->simple_accessor('level');
BN->simple_accessor('input', 'input');
BN->simple_accessor('output', 'output');
BN->simple_accessor('xp_output', 'XPoutput');
BN->simple_accessor('queue_size', 'maximumHealingQueueSize');
BN->simple_accessor('time', 'time');

BN->accessor(cost => sub {
   my ($level) = @_;
   return BN->flatten_amount(delete($level->{upgradeCost}),
      delete($level->{upgradeTime}));
});

1 # end BN::Building::Level
