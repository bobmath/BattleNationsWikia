package BN::Out::Levels;
use strict;
use warnings;
use Data::Dump qw( dump );

sub write {
   my $levels = BN::JSON->read('Levels.json');
   my $num_levels = keys %$levels;

   my $expand = BN::JSON->read('ExpandLandCosts.json');
   my @land_total = (4);
   my @land_change = (0);
   foreach my $exp (@$expand) {
      my $prereqs = $exp->{prereq} or next;
      foreach my $key (sort keys %$prereqs) {
         my $prereq = $prereqs->{$key} or next;
         my $t = $prereq->{_t} or next;
         if ($t eq 'LevelPrereqConfig') {
            my $level = $prereq->{level} or next;
            $land_change[$level]++;
         }
      }
   }
   for my $level (1 .. $num_levels) {
      my $change = $land_change[$level] ||= 0;
      $land_total[$level] = $land_total[$level-1] + $change;
   }

   my @unlocked;
   foreach my $unit (BN::Unit->all()) {
      next unless $unit->building();
      next if $unit->visibility_prereq();
      my $level = $unit->level() or next;
      push @{$unlocked[$level]}, $unit->wikilink();
   }
   foreach my $bld (BN::Building->all()) {
      next unless $bld->build_menu();
      my $level = $bld->level() || 1;
      push @{$unlocked[$level]}, $bld->wikilink();
   }

   my $file = BN::Out->filename('missions', 'Levels');
   open my $F, '>', $file or die "Can't write $file: $!";

   print $F "Levels\n\n";

   print $F qq({| class="wikitable standout"\n|-\n! Level !! XP Needed !! ),
      "Reward !! Unlocked !! Population !! Districts\n";

   my $prev_pop = $levels->{1}{populationLimit};
   my $next_xp = '-';
   for my $level (1 .. $num_levels) {
      my $lev = $levels->{$level} or next;
      print $F qq{|-\n! <div id="$level">$level</div>\n};

      print $F "| $next_xp\n";
      $next_xp = '{{XP|' . BN->commify($lev->{nextLevelXp}) . '}}';

      print $F "| ", BN->format_amount($lev->{awards})||'-', "\n";

      if (my $unlocked = $unlocked[$level]) {
         print $F "| ", join(', ', sort @$unlocked), "\n";
      }
      else {
         print $F "| -\n";
      }

      my $pop = $lev->{populationLimit};
      if ($pop > $prev_pop) {
         my $diff = $pop - $prev_pop;
         print $F "| {{PopulationPlus|$pop (+$diff)}}\n";
      }
      else {
         print $F "| {{Population|$pop}}\n";
      }
      $prev_pop = $pop;

      if ($land_change[$level]) {
         print $F "| $land_total[$level] (+$land_change[$level])\n";
      }
      else {
         print $F "| $land_total[$level]\n";
      }
   }

   print $F "|-\n! MAX\n| $next_xp\n| {{Stars|15}}\n| -\n";
   print $F "| {{Population|$prev_pop}}\n";
   print $F "| $land_total[$num_levels]\n";
   print $F "|}\n\n";

   print $F dump($levels), "\n", dump($expand), "\n";
   close $F;
   BN::Out->checksum($file);
}

1 # end BN::Out::Levels
