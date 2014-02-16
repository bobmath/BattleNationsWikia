package BN::Out::Buildings;
use strict;
use warnings;
use BN::Out;
use Data::Dump qw( dump );

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

   my ($weap) = $unit->weapons() or return;
   my ($attack) = $weap->attacks() or return;
   print $F "{{UnitAttackBox\n";
   print_line($F, 'attackname', $attack->name());
   print_line($F, 'weapon', $weap->name());
   print_line($F, 'offense', $attack->offense());

   if (my $type = $attack->dmgtype()) {
      my $min = $attack->mindmg();
      my $max = $attack->maxdmg();
      my $num = $attack->numattacks();
      $max .= " (x$num)" if $num;
      print_line($F, 'damage', "{{$type|$min-$max}}");
   }

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

sub building_levels {
   my ($F, $build) = @_;
   my @levels = $build->levels() or return;
   print $F "{{BuildingLevelBox\n";
   level_costs($F, $build, \@levels);
   print $F "}}\n\n";
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

sub print_line {
   my ($F, $tag, $val) = @_;
   printf $F "| %-14s = %s\n", $tag, $val if defined $val;
}

1 # end BN::Out::Buildings
