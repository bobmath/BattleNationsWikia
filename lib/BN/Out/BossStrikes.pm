package BN::Out::BossStrikes;
use strict;
use warnings;
use Data::Dump qw( dump );

sub write {
   my %unit_names;
   foreach my $unit (BN::Unit->all()) {
      my $side = $unit->side() or next;
      $unit_names{$unit->name()} |= 1 if $side eq 'Player';
      $unit_names{$unit->name()} |= 2 if $side eq 'Hostile';
   }

   my $encounters = BN::JSON->read('BattleEncounters.json');

   foreach my $strike (BN::BossStrike->all()) {
      my $file = BN::Out->filename('strikes', $strike->name());
      open my $F, '>', $file or die "Can't write $file: $!";

      my @tiers = $strike->tiers();
      push @tiers, $tiers[-1]->extend() for 1..2;

      print $F qq({| class="wikitable standout"\n);
      print $F "|-\n! Tier !! Rewards !! Points awarded",
         " !! Points to earn !! Total points\n";
      my $sum;
      foreach my $tier (@tiers) {
         my $rewards = BN->format_amount($tier->rewards()) || '-';
         my $award = join('', BN->format_amount($tier->cost()), " &rarr; ",
            '{{BSPoints|', BN->commify($tier->points_awarded()), '}}');
         my $pts = $tier->points_needed();
         $sum += $pts;
         print $F qq{|- align="center"\n};
         print $F '! ', $tier->tier(), "\n";
         print $F '| ', join(' || ', $rewards, $award,
            BN->commify($pts), BN->commify($sum)), "\n";
      }
      print $F "|}\n\n";

      my %encounters;
      foreach my $tier ($strike->tiers()) {
         foreach my $encounter (@{$tier->{encounters}}) {
            $encounters{$encounter->{encounterId}} = 1;
         }
      }

      my %units;
      foreach my $key (keys %encounters) {
         my $army = $encounters->{armies}{$key} or next;
         my $units = $army->{units} or next;
         foreach my $unit (@$units) {
            $units{$unit->{unitId}} = 1;
         }
      }

      my %names;
      foreach my $key (keys %units) {
         my $unit = BN::Unit->get($key) or next;
         my $name = $unit->name();
         my $flag = $unit_names{$name} or next;
         if ($flag == 3) {
            $names{"[[$name (enemy)|$name]]"} = 1;
         }
         else {
            $names{"[[$name]]"} = 1;
         }
      }

      my @names = sort keys %names;
      my $break = 0;
      print $F "{|\n|-\n";
      foreach my $i (0 .. $#names) {
         if ($i >= $break) {
            print $F "|\n";
            $break += int((@names+2)/3);
         }
         print $F "*$names[$i]\n";
      }
      print $F "|}\n\n";

      print $F dump($strike), "\n";
      close $F;
      BN::Out->checksum($file);
   }
}

1 # end BN::Out::BossStrikes
