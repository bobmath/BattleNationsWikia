package BN::Reward;
use strict;
use warnings;

my $rewards_table;

sub get {
   my ($class, $key) = @_;
   return unless $key;
   $rewards_table ||= BN::File->json('RewardTables.json');
   my $table = $rewards_table->{rewardsMap}{$key} or return;
   my $list = $table->{list} or return;
   my %rewards;

   foreach my $item (@$list) {
      if (my $res = $item->{resources}) {
         while (my ($k, $v) = each %$res) {
            $rewards{$BN::resource_map{$k} || $k} = format_chance($v);
         }
      }
      if (my $units = $item->{units}) {
         while (my ($k, $v) = each %$units) {
            $rewards{units}{$k} = format_chance($v);
         }
      }
   }

   return unless %rewards;
   return \%rewards;
}

sub format_chance {
   my ($dat) = @_;
   return unless $dat;
   my $range = $dat->{range} or return;
   my $num = $range->{min} or return;
   my $max = $range->{max} or return;
   $num .= '-' . $max if $max > $num;
   if (my $percent = $dat->{percent}) {
      $num .= " ($percent% chance)" if $percent < 100;
   }
   return $num;
}

sub get_rewards {
   my ($tag) = @_;
   return unless $tag;
   $rewards_table ||= BN::File->json('RewardTables.json');
   my $rewards = $rewards_table->{rewardsMap}{$tag} or return;
   my $list = $rewards->{list} or return;
   my @rewards;

   foreach my $item (@$list) {
      my $levels = $item->{levels};
      my $lmin = $levels->{min} || 1;
      my $lmax = $levels->{max} || 70;
      $lmax = 70 if $lmax > 70;

      if (my $money = $item->{money}) {
         push @rewards, new_reward(rsrc => 'money', $money, $lmin, $lmax);
      }

      if (my $rsrc = $item->{resources}) {
         foreach my $key (sort keys %$rsrc) {
            push @rewards,
               new_reward(rsrc => $key, $rsrc->{$key}, $lmin, $lmax);
         }
      }

      if (my $units = $item->{units}) {
         foreach my $key (sort keys %$units) {
            push @rewards,
               new_reward(unit => $key, $units->{$key}, $lmin, $lmax);
         }
      }

      if (my $ref = $item->{rewardsRefCount}) {
         my $range = $ref->{range} or next;
         my $min = $range->{min} or next;
         my $max = $range->{max} or next;
         my $mean = ($min + $max) / 2;
         my $chance = $ref->{percent} || $ref->{chance} || 100;
         $chance = 100 if $chance > 100;
         $chance /= 100;
         my $ref_rewards = get_rewards($item->{rewardsRef}) or next;
         foreach my $ref_item (@$ref_rewards) {
            next if $ref_item->{lmax} < $lmin || $ref_item->{lmin} > $lmax;
            $ref_item->{lmin} = $lmin if $ref_item->{lmin} < $lmin;
            $ref_item->{lmax} = $lmax if $ref_item->{lmax} > $lmax;
            $ref_item->{min} *= $min;
            $ref_item->{max} *= $max;
            $ref_item->{mean} *= $mean;
            $ref_item->{pct} *= $chance;
            push @rewards, $ref_item;
         }
      }
   }

   return \@rewards;
}

sub new_reward {
   my ($type, $id, $info, $lmin, $lmax) = @_;
   my $range = $info->{range};
   my $min = $range->{min};
   my $max = $range->{max};
   my $pct = $info->{percent} || $info->{chance} || 100;
   $pct = 100 if $pct > 100;
   return {
      type => $type,
      kind => $id,
      pct => $pct,
      min => $min,
      max => $max,
      mean => ($min + $max) / 2,
      lmin => $lmin,
      lmax => $lmax,
   };
}

sub merge_rewards {
   my ($in) = @_;
   my %index;
   foreach my $item (@$in) {
      my $key = "$item->{type} $item->{kind}";
      $index{$key}{$item->{lmin}-1} = 1;
      $index{$key}{$item->{lmax}} = 1;
   }

   foreach my $key (keys %index) {
      $index{$key} = [ sort {$a<=>$b} keys %{$index{$key}} ];
   }

   my @temp;
   foreach my $item (sort { $a->{lmin} <=> $b->{lmin}
      || $a->{lmax} <=> $b->{lmax} || $a->{kind} cmp $b->{kind} } @$in)
   {
      my @split = grep { $_ >= $item->{lmin} && $_ < $item->{lmax} }
         @{$index{"$item->{type} $item->{kind}"}};
      my $low = $item->{lmin};
      foreach my $split (@split) {
         push @temp, { %$item, lmin => $low, lmax => $split };
         $low = $split + 1;
      }
      push @temp, { %$item, lmin => $low };
   }

   %index = ();
   my @out;
   foreach my $item (@temp) {
      my $key = "$item->{type} $item->{kind} $item->{lmin} $item->{lmax}";
      if (my $old = $index{$key}) {
         my $pct = $old->{pct} + $item->{pct}
            - $old->{pct} * $item->{pct} / 100;
         if ($item->{pct} < 100) {
            $old->{min} = $item->{min}
               if $old->{pct} < 100 && $item->{min} < $old->{min};
         }
         elsif ($old->{pct} < 100) {
            $old->{min} = $item->{min};
         }
         else {
            $old->{min} += $item->{min};
         }
         $old->{mean} = ($old->{pct} * $old->{mean}
            + $item->{pct} * $item->{mean}) / $pct;
         $old->{max} += $item->{max};
         $old->{pct} = $pct;
      }
      else {
         $index{$key} = $item;
         push @out, $item;
      }
   }
   return \@out;
}

1 # end BN::Reward
