package BN::Out::Levels;
use strict;
use warnings;

sub write {
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

   my $prev_pop = 20;
   my $prev_land = 4;
   my $next_xp = '-';
   for my $level (1 .. BN::Level->max()) {
      my $lev = BN::Level->get($level) or die;
      print $F qq{|-\n! <div id="$level">$level</div>\n};

      print $F "| $next_xp\n";
      $next_xp = '{{XP|' . BN->commify($lev->next_xp()) . '}}';

      print $F "| ", $lev->rewards()||'-', "\n";

      if (my $unlocked = $unlocked[$level]) {
         print $F "| ", join(', ', sort @$unlocked), "\n";
      }
      else {
         print $F "| -\n";
      }

      my $pop = $lev->population();
      if ($pop > $prev_pop) {
         my $diff = $pop - $prev_pop;
         print $F "| {{PopulationPlus|$pop (+$diff)}}\n";
      }
      else {
         print $F "| {{Population|$pop}}\n";
      }
      $prev_pop = $pop;

      my $land = $lev->land();
      if ($land > $prev_land) {
         my $diff = $land - $prev_land;
         print $F "| $land (+$diff)\n";
      }
      else {
         print $F "| $land\n";
      }
      $prev_land = $land;
   }

   print $F "|-\n! MAX\n| $next_xp\n| {{Stars|15}}\n| -\n",
      "| {{Population|$prev_pop}}\n| $prev_land\n|}\n\n";

   close $F;
   BN::Out->checksum($file);
}

1 # end BN::Out::Levels
