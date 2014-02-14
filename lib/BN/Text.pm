package BN::Text;
use strict;
use warnings;

my $text;

sub get {
   my ($class, $key) = @_;
   return 'none' unless defined $key;
   unless ($text) {
      $text = BN::JSON->read('BattleNations_en.json');
      my $delta = BN::JSON->read('Delta_en.json');
      while (my ($k,$v) = each %$delta) {
         $text->{$k} = $v;
      }
   }
   return $text->{lc($key)} // $text->{$key} // $key;
}

1 # end BN::Text
