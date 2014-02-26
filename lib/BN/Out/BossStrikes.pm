package BN::Out::BossStrikes;
use strict;
use warnings;
use Data::Dump qw( dump );

sub write {
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
         $pts /= 10 if $pts > 10_000_000 && $tier->tier() < 10; # kludge
         $sum += $pts;
         print $F qq{|- align="center"\n};
         print $F '! ', $tier->tier(), "\n";
         print $F '| ', join(' || ', $rewards, $award,
            BN->commify($pts), BN->commify($sum)), "\n";
      }
      print $F "|}\n";

      print $F "\n", dump($strike), "\n";
      close $F;
      BN::Out->checksum($file);
   }
}

1 # end BN::Out::BossStrikes
