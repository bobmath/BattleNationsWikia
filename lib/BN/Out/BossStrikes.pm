package BN::Out::BossStrikes;
use strict;
use warnings;
use Data::Dump qw( dump );

sub write {
   foreach my $strike (BN::BossStrike->all()) {
      my $file = BN::Out->filename('strikes', $strike->name());
      open my $F, '>', $file or die "Can't write $file: $!";
      show_tiers($F, $strike);
      show_enemies($F, $strike);
      print $F dump($strike), "\n";
      close $F;
      BN::Out->checksum($file);
   }
}

sub show_tiers {
   my ($F, $strike) = @_;
   my @tiers = $strike->tiers();
   push @tiers, $tiers[-1]->extend() for 1..2;

   print $F qq(==Rewards==\n{| class="wikitable standout"\n);
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
}

sub show_enemies {
   my ($F, $strike) = @_;
   my (%encounters, %levels);
   foreach my $encounter (@{$strike->{globalEventEncounters}}) {
      add_encounter($encounter, \%encounters, \%levels, 0);
   }
   my $tnum;
   foreach my $tier ($strike->tiers()) {
      ++$tnum;
      foreach my $encounter (@{$tier->{encounters}}) {
         add_encounter($encounter, \%encounters, \%levels, $tnum);
      }
   }

   my %units;
   foreach my $key (sort keys %encounters) {
      my $einf = $encounters{$key} or next;
      my $encounter = BN::Encounter->get($key) or next;
      foreach my $id ($encounter->unit_ids()) {
         my $unit = BN::Unit->get($id) or next;
         my $link = $unit->wikilink();
         if (my $uinf = $units{$unit->name()}) {
            # prefer link with (enemy) tag
            $uinf->{link} = $link if length($link) > length($uinf->{link});
            $uinf->{min} = $einf->{min} if $einf->{min} < $uinf->{min};
            $uinf->{max} = $einf->{max} if $einf->{max} > $uinf->{max};
         }
         else {
            $units{$unit->name()} = { link => $link,
               min => $einf->{min}, max => $einf->{max} };
         }
      }
   }

   print $F "==Enemies==\n",
      qq({| class="wikitable mw-collapsible mw-collapsed"\n),
      "! Unit !! Levels\n";
   foreach my $name (sort keys %units) {
      my $inf = $units{$name} or next;
      print $F "|-\n| $inf->{link}\n",
         qq{| align="right" | $inf->{min}-$inf->{max}\n};
   }
   print $F "|}\n\n";

   foreach my $levels (sort keys %levels) {
      my $tiers = $levels{$levels} or next;
      print $F "==Level $levels==\n";
      my @tiers = sort {$a <=> $b} keys %$tiers;
      while (@tiers) {
         my $tnum = shift @tiers;
         my $eids = $tiers->{$tnum} or next;
         if ($tnum) {
            my $eidstr = join ',', sort keys %$eids;
            my $hinum = $tnum;
            while (@tiers) {
               my $nextnum = $tiers[0];
               my $nextids = $tiers->{$nextnum} or last;
               my $nextstr = join ',', sort keys %$nextids;
               last unless $nextstr eq $eidstr;
               $hinum = $nextnum;
               shift @tiers;
            }
            if ($tnum == $hinum) { print $F "===Tier $tnum===\n" }
            else { print $F "===Tier $tnum-$hinum===\n" }
         }
         my $enum;
         foreach my $eid (sort keys %$eids) {
            show_encounter($F, BN::Encounter->get($eid), ++$enum);
         }
      }
   }
   print $F "\n";
}

sub add_encounter {
   my ($enc, $encounters, $levels, $tier) = @_;
   my $id = $enc->{encounterId} or return;
   my $max_level = BN::Level->max();
   my $min = $enc->{minLevel} || 1;
   my $max = $enc->{maxLevel} || $max_level;
   $max = $max_level if $max > $max_level;
   if (my $info = $encounters->{$id}) {
      $info->{min} = $min if $min < $info->{min};
      $info->{max} = $max if $max > $info->{max};
   }
   else {
      $encounters->{$id} = { min=>$min, max=>$max };
   }
   $levels->{"$min-$max"}{$tier}{$id} = 1;
}

sub show_encounter {
   my ($F, $enc, $num) = @_;
   return unless $enc;
   my $waves = $enc->waves() or return;
   my $file = ucfirst($enc->tag());
   print $F "[[File:$file.png]]<br>\n";
   print $F "Battle $num:\n";
   my $wnum;
   foreach my $wave (@$waves) {
      $wnum++;
      next unless $wave;
      my %links;
      foreach my $id (@$wave) {
         my $unit = BN::Unit->get($id) or next;
         $links{$unit->shortname()}{$unit->shortlink()}++;
      }
      my @links;
      foreach my $nm (sort keys %links) {
         my $lks = $links{$nm} or next;
         foreach my $link (sort keys %$lks) {
            my $num = $lks->{$link} || 1;
            $link .= ' x ' . $num if $num > 1;
            push @links, $link;
         }
      }
      my $links = join ', ', @links;
      print $F "* Wave $wnum: $links\n" if $links;
   }
}

1 # end BN::Out::BossStrikes
