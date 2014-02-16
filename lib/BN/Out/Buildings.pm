package BN::Out::Buildings;
use strict;
use warnings;
use BN::Out;
use Data::Dump qw( dump );
use POSIX qw( ceil );

sub write {
   mkdir 'buildings';
   mkdir 'other';
   foreach my $build (BN::Building->all()) {
      my $dir = $build->build_menu() ? 'buildings' : 'other';
      my $file = BN::Out->filename($dir, $build->name());
      print $file, "\n";
      open my $F, '>', $file or die "Can't write $file: $!";;

      building_summary($F, $build);
      building_defense($F, $build);
      building_levels($F, $build);
      orchard($F, $build);

      print $F "\n", dump($build), "\n";
      close $F;
      BN::Out->checksum($file);
   }
}

my %cost_map = (
   merits   => 'merit',
   nanopods => 'nano',
   skulls   => 'skull',
   stars    => 'star',
   z2points => 'z2',
);

sub building_summary {
   my ($F, $build) = @_;
   print $F $build->name(), "\n";
   print $F "{{BuildingInfoBox\n";
   print_line($F, 'buildtype', $build->build_type());
   print_line($F, 'population', $build->population());
   print_line($F, 'pwi', $build->population_inactive());
   print_line($F, 'size', $build->size());

   my @unlock;
   if (my $level = $build->level()) {
      push @unlock, "[[Levels#$level|Level $level]]";
   }
   push @unlock, 'Mission' if $build->mission_req();
   push @unlock, 'Unique' if $build->unique();
   print_line($F, 'unlocked', join(', ', @unlock)) if @unlock;

   print_line($F, 'bonustype', $build->gets_bonus());

   print_line($F, 'dradius', $build->defense_radius());
   print_line($F, 'garrison', $build->garrison_size());
   print_line($F, 'repairtime', $build->repair_time());

   if (my $cost = $build->cost()) {
      print_line($F, 'cost', 'true');
      foreach my $key (BN->sort_amount(keys %$cost)) {
         my $k = ($cost_map{$key} || $key) . 'cost';
         my $fmt = $key eq 'time' ? 'format_time' : 'commify';
         print_line($F, $k, BN->$fmt($cost->{$key}));
      }
   }

   print_line($F, 'assistreward', BN->format_amount($build->assist_reward()));
   print_line($F, 'maxassists', $build->max_assists());
   print_line($F, 'assistbonus', $build->assist_bonus());
   print_line($F, 'raidreward', BN->format_amount($build->raid_reward()));
   print_line($F, 'occupyreward', BN->format_amount($build->occupy_reward()));
   print_line($F, 'sell', BN->format_amount($build->sell_price()));

   print_line($F, 'game file name', $build->tag());
   print $F "}}\n\n";
}

sub building_defense {
   my ($F, $build) = @_;
   my $unit = BN::Unit->get($build->defense()) or return;
   print $F "{{UnitInfobox\n";
   print_line($F, 'shortname', $unit->shortname())
      unless $unit->shortname() eq $build->name();
   print_line($F, 'blocking', $unit->blocking());
   print_line($F, 'immunities', $unit->immunities());

   if (my ($rank) = $unit->ranks()) {
      print_line($F, 'hp', $rank->hp());
      print_line($F, 'armor', $rank->armor() || undef);
      print_line($F, 'bravery', $rank->bravery());
      print_line($F, 'defense', $rank->defense());
      print_line($F, 'dodge', $rank->dodge() || undef);
      BN::Out::Units::damage_mods($F, 'armor', $rank->armor_mods())
         if $unit->max_armor();
      BN::Out::Units::damage_mods($F, 'base', $rank->damage_mods());
      print_line($F, 'uv', $rank->uv());
   }

   print_line($F, 'nocat', 'true');
   print_line($F, 'game file name', $unit->tag());
   print $F "}}\n\n";

   foreach my $weap ($unit->weapons()) {
      foreach my $attack ($weap->attacks()) {
         print $F "{{UnitAttackBox\n";
         print_line($F, 'attackname', $attack->name());
         print_line($F, 'weapon', $weap->name());
         print_line($F, 'offense', $attack->offense());
         print_line($F, 'damage', $attack->damage());
         print_line($F, 'armorpiercing', $attack->armorpiercing());
         print_line($F, 'crit', $attack->crit());
         print_line($F, 'range', $attack->range());
         print_line($F, 'lof', $attack->lof());
         print_line($F, 'cooldown', $attack->cooldown());
         print_line($F, 'ammo', $weap->ammo());
         print_line($F, 'reload', $weap->reload());
         print_line($F, 'effects', $attack->effects());
         print_line($F, 'targets', $attack->targets());
         print_line($F, 'game file name', $attack->tag());
         print $F "}}\n\n";
      }
   }
}

sub building_levels {
   my ($F, $build) = @_;
   my @levels = $build->levels() or return;
   print $F "{{BuildingLevelBox\n";
   level_tax($F, $build, \@levels);
   level_resource($F, $build, \@levels);
   level_costs($F, $build, \@levels);
   print $F "}}\n\n";
}

sub level_tax {
   my ($F, $build, $levels) = @_;
   my $tax = $build->taxes() or return;
   if (my $time = BN->format_time($tax->{time})) {
      print_line($F, 'interval', "{{Time|$time}}");
   }
   if (my $gold = $tax->{gold}) {
      print_line($F, 'collector', 'true');
      print_line($F, 'resource', '{{Gold}}');
      print_uv($F, $gold, $levels);
   }
   if (my $xp = $tax->{XP}) {
      print_line($F, 'xphousing', 'true');
      my $n;
      foreach my $level (@$levels) {
         ++$n;
         my $output = $level->xp_output() or next;
         my $val = ceil($xp * $output / 100);
         print_line($F, 'xp' . $n, BN->commify($val));
      }
   }
}

sub level_resource {
   my ($F, $build, $levels) = @_;
   my $rate = $build->resource_rate() or return;
   print_line($F, 'collector', 'true');
   print_line($F, 'interval', '{{Time|1h}}');
   print_line($F, 'resource', BN->resource_template($build->resource_type()));
   print_uv($F, $rate, $levels);
}

sub print_uv {
   my ($F, $val, $levels) = @_;
   my $n;
   foreach my $level (@$levels) {
      ++$n;
      my $output = $level->output() or next;
      my $uv = ceil($val * $output / 100);
      print_line($F, 'uv' . $n, BN->commify($uv));
   }
}

sub level_costs {
   my ($F, $build, $levels) = @_;
   my @cost = ( $build->cost(), map { $_->cost() } @$levels );
   pop @cost;

   my %resources;
   foreach my $cost (@cost) {
      while (my ($key,$val) = each %$cost) {
         $resources{$key} = 1;
      }
   }
   my @resources = BN->sort_amount(keys %resources);

   foreach my $key (@resources) {
      my $name = ($cost_map{$key} || $key) . 'cost';
      print_line($F, $name, 'true');
      my $fmt = $key eq 'time' ? 'format_time' : 'commify';
      my $n;
      foreach my $cost (@cost) {
         print_line($F, $name . ++$n, BN->$fmt($cost->{$key}));
      }
   }
}

sub orchard {
   my ($F, $build) = @_;
   return if $build->levels();
   my $tax = $build->taxes() or return;
   print $F "{{OrchardGoodsBox\n";
   print_line($F, 'good1time', BN->format_time($tax->{time}));
   print_line($F, 'good1xp', $tax->{XP});
   print_line($F, 'good1gold', $tax->{gold});
   print $F "}}\n\n";
}

sub print_line {
   my ($F, $tag, $val) = @_;
   printf $F "| %-14s = %s\n", $tag, $val if defined $val;
}

1 # end BN::Out::Buildings
