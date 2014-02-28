package BN::Level;
use strict;
use warnings;

my $levels;
my $json_file = 'Levels.json';

sub max {
   $levels ||= BN::JSON->read($json_file);
   return scalar keys %$levels;
}

sub get {
   my ($class, $key) = @_;
   return unless $key;
   $levels ||= BN::JSON->read($json_file);
   my $lev = $levels->{$key} or return;
   if (ref($lev) eq 'HASH') {
      bless $lev, $class;
      $lev->{_level} = $key;
   }
   return $lev;
}

BN->simple_accessor('level');
BN->simple_accessor('population', 'populationLimit');
BN->simple_accessor('next_xp', 'nextLevelXp');

BN->accessor(rewards => sub {
   my ($lev) = @_;
   return BN->format_amount(delete $lev->{awards});
});

sub land {
   my ($lev) = @_;
   return $lev->{_land} if exists $lev->{_land};

   my $expand = BN::JSON->read('ExpandLandCosts.json');
   my @land = (0) x (BN::Level->max() + 1);
   foreach my $exp (@$expand) {
      my $prereqs = $exp->{prereq} or next;
      foreach my $key (sort keys %$prereqs) {
         my $prereq = $prereqs->{$key} or next;
         my $t = $prereq->{_t} or next;
         if ($t eq 'LevelPrereqConfig') {
            my $level = $prereq->{level} or next;
            $land[$level]++;
         }
      }
   }

   my $sum = 4;
   for my $level (1 .. $#land) {
      $sum += $land[$level];
      my $lev = BN::Level->get($level) or die "missing level $level";
      $lev->{_land} = $sum;
   }

   return $lev->{_land};
}

1 # end BN::Level
