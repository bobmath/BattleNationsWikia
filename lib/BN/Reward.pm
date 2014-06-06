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

1 # end BN::Reward
