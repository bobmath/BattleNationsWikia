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
      orchard_goods($F, $build);
      building_goods($F, $build);
      quest_goods($F, $build);
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

my %reward_cat = (
   'XP gold time' => '{{GoldXP}}',
   'gold time'    => '{{Gold}}',
);

my %demand_map = (
   Spices   => 'Spice',
   Defense  => 'Security',
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
   if (my $id = $build->mission_req()) {
      if (my $mis = BN::Mission->get($id)) {
         my $name = $mis->name();
         push @unlock, "[[Missions#$name|$name]]";
      }
   }
   push @unlock, 'Unique' if $build->unique();
   print_line($F, 'unlocked', join(', ', @unlock)) if @unlock;

   if (my $cat = $build->demand_cat()) {
      $cat = $demand_map{$cat} || $cat;
      print_line($F, 'demandcat', "{{$cat}}");
   }

   if (my $rsrc = $build->resource_type()) {
      $rsrc = ucfirst($rsrc);
      print_line($F, 'resource', "{{$rsrc}} [[Resources#$rsrc|$rsrc]]");
   }

   if (my $tax = $build->taxes()) {
      my $keys = join ' ', sort keys %$tax;
      print_line($F, 'rewardcat', $reward_cat{$keys});
   }

   print_line($F, 'bonustype', $build->gets_bonus());

   if (my $bonus = $build->gives_bonus()) {
      print_line($F, 'bonus', $bonus);
      print_line($F, 'bonusbldg', $build->gives_bonus_to());
      print_line($F, 'bonusradius', $build->bonus_radius());
      print_line($F, 'bldglimit', $build->bonus_stack());
   }

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
   if (my $type = $build->input_type()) {
      if ($type eq 'hospitalInput' || $type eq 'repairCost') {
         hospital_levels($F, \@levels);
      }
      elsif ($type eq 'barracksInput') {
         barracks_levels($F, \@levels);
      }
   }
   if (my $type = $build->output_type()) {
      if ($type eq 'millOutput') {
         mill_levels($F, $build, \@levels);
      }
   }
   level_costs($F, $build, \@levels);
   print $F "}}\n\n";
}

sub hospital_levels {
   my ($F, $levels) = @_;
   print_line($F, 'hospital', 'true');

   my $n;
   foreach my $level (@$levels) {
      ++$n;
      my $input = $level->input() or next;
      print_line($F, 'cr' . $n, int(100*(1-$input/150)+0.5));
   }

   $n = 0;
   foreach my $level (@$levels) {
      ++$n;
      print_line($F, 'qs' . $n, $level->queue_size() + 1);
   }

   $n = 0;
   foreach my $level (@$levels) {
      ++$n;
      my $time = $level->time() or next;
      print_line($F, 'tr' . $n, 100-$time);
   }
}

sub barracks_levels {
   my ($F, $levels) = @_;
   print_line($F, @$levels == 10 ? 'training10' : 'training', 'true');

   my $n;
   foreach my $level (@$levels) {
      ++$n;
      my $input = $level->input() or next;
      print_line($F, 'cr' . $n, 100-$input);
   }

   my $timebase = $levels->[0]->time() or return;
   $n = 0;
   foreach my $level (@$levels) {
      ++$n;
      my $time = $level->time() or next;
      print_line($F, 'tr' . $n, int(100*(1-$time/$timebase)+0.5));
   }
}

sub mill_levels {
   my ($F, $build, $levels) = @_;
   my $rate = $build->mill_rate() or return;
   print_line($F, 'collector', 'true');
   print_line($F, 'resource', BN->resource_template($build->mill_output()));
   print_line($F, 'interval', '{{Time|1d}}');
   $rate *= 100 / $levels->[0]->output();
   print_uv($F, $rate, $levels);
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

sub orchard_goods {
   my ($F, $build) = @_;
   return if $build->levels();
   my $tax = $build->taxes() or return;
   return if keys(%$tax) > 3;
   print $F "{{OrchardGoodsBox\n";
   print_line($F, 'float', 'left');
   print_line($F, 'good1time', BN->format_time($tax->{time}));
   print_line($F, 'good1xp', $tax->{XP});
   print_line($F, 'good1gold', $tax->{gold});
   print $F "}}\n\n";
}

sub building_goods {
   my ($F, $build) = @_;
   my @jobs = $build->jobs() or return;
   my $type = $build->output_type() or return;
   if ($type eq 'shopOutput') {
      shop_goods($F, $build, \@jobs);
   }
   elsif ($type eq 'millOutput') {
      mill_goods($F, $build, \@jobs);
   }
}

sub shop_goods {
   my ($F, $build, $jobs) = @_;
   print $F "{{ShopGoodsBox\n";
   my $n;
   for my $job (@$jobs) {
      my $g = 'good' . ++$n;
      print_line($F, $g, $job->name());
      if (my $cost = $job->cost()) {
         print_line($F, $g.'time', BN->format_time($cost->{time}));
         print_line($F, $g.'basecost', $cost->{gold});
      }
      if (my $rewards = $job->rewards()) {
         print_line($F, $g.'xp', $rewards->{XP});
         print_line($F, $g.'basereward', $rewards->{gold});
      }
   }
   print $F "}}\n\n";
}

sub mill_goods {
   my ($F, $build, $jobs) = @_;
   my @input = $build->mill_input() or return;
   my $output = $build->mill_output() or return;
   print $F "{{MillGoodsBox\n";
   my $n;
   print_line($F, 'input' . ++$n, BN->resource_template($_)) foreach @input;
   print_line($F, 'output', BN->resource_template($output));
   $n = 0;
   foreach my $job (@$jobs) {
      my $g = 'good' . ++$n;
      print_line($F, $g, $job->name());
      if (my $cost = $job->cost()) {
         print_line($F, $g.'time', BN->format_time($cost->{time}));
         my $i;
         print_line($F, $g.'baseinput'.++$i, $cost->{$_}) foreach @input;
      }
      if (my $rewards = $job->rewards()) {
         print_line($F, $g.'baseoutput', $rewards->{$output});
      }
   }
   print $F "}}\n\n";
}

sub quest_goods {
   my ($F, $build) = @_;
   my @jobs = $build->quest_jobs() or return;
   print $F "{{QuestGoodsListBox\n";
   my $n = 0;
   foreach my $job (@jobs) {
      if ($n >= 10) {
         # too many, start a new list box
         print $F "}}\n{{QuestGoodsListBox\n";
         print_line($F, 'continue', 'true');
         $n = 0;
      }
      my $g = 'good' . ++$n;
      my $name = $job->name();
      my ($id) = $job->missions() or die;
      my $mis = BN::Mission->get($id) or die;
      my $mname = $job->name();
      print_line($F, $g, "[[Missions#$mname|$name]]");
      if (my $icon = $job->icon()) {
         print_line($F, $g.'image', "[[File:\u$icon.png|link=]]");
      }
      if (my $cost = $job->cost()) {
         print_line($F, $g.'time', BN->format_time($cost->{time}));
         print_line($F, $g.'cost',
            BN->format_amount({%$cost, time=>0}, 0, ' &nbsp; '));
      }
      print_line($F, $g.'reward',
         BN->format_amount($job->rewards(), 0, ' &nbsp; '));
   }
   print $F "}}\n\n";
}

sub print_line {
   my ($F, $tag, $val) = @_;
   printf $F "| %-15s = %s\n", $tag, $val if defined $val;
}

1 # end BN::Out::Buildings
