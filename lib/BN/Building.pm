package BN::Building;
use strict;
use warnings;
use POSIX qw( ceil );

my $buildings;
my $json_file = 'Compositions.json';

sub all {
   my ($class) = @_;
   $buildings ||= BN::JSON->read($json_file);
   return map { $class->get($_) } sort keys %$buildings;
}

sub get {
   my ($class, $key) = @_;
   $buildings ||= BN::JSON->read($json_file);
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
      else {
         $build->{_name} = 'noname';
      }
   }
   return $build;
}

BN->simple_accessor('tag');
BN->simple_accessor('name');

sub units {
   my ($build) = @_;
   my $projects = $build->{ProjectList} or return;
   my $jobs = $projects->{jobs} or return;
   return @$jobs;
}

sub level {
   my ($build) = @_;
   return $build->{_level} if exists $build->{_level};
   BN::Prereqs->calc_levels();
   return $build->{_level};
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

   my $buildable = BN::JSON->read('StructureMenu.json');

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

BN->accessor(assist_reward => sub {
   my ($build) = @_;
   my $assist = $build->{Assistance} or return;
   return BN->flatten_amount(delete($assist->{rewards}));
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
   return map { BN::BLevel->new($_, ++$n) } @$levels;
});

BN->accessor(gets_bonus => sub {
   my ($build) = @_;
   return if $build->{ResourceProducer};
   my $buff = $build->{RadialModBuffable} or return;
   my $tags = $buff->{tags} or return;
   my @tags = grep { $_ ne 'all' } @$tags or return;
   return join ', ', sort @tags;
});

1 # end BN::Building
