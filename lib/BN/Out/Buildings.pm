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

sub building_levels {
   my ($F, $build) = @_;
   my @levels = $build->levels() or return;
   my @cost = ( $build->cost(), map { $_->cost() } @levels );
   pop @cost;

   my %resources;
   foreach my $cost (@cost) {
      while (my ($key,$val) = each %$cost) {
         $resources{$key} = 1;
      }
   }
   my @resources = BN->sort_amount(keys %resources);

   print $F "{{BuildingLevelBox\n";

   foreach my $key (@resources) {
      my $name = ($cost_map{$key} || $key) . 'cost';
      print_line($F, $name, 'true');
      my $fmt = $key eq 'time' ? 'format_time' : 'commify';
      my $n;
      foreach my $cost (@cost) {
         print_line($F, $name . ++$n, BN->$fmt($cost->{$key}));
      }
   }

   print $F "}}\n\n";
}

sub print_line {
   my ($F, $tag, $val) = @_;
   printf $F "| %-14s = %s\n", $tag, $val if defined $val;
}

1 # end BN::Out::Buildings
