package BN::Text;
use strict;
use warnings;

my $text;

sub load_text {
   return if $text;
   $text = BN::JSON->read('BattleNations_en.json');
   my $delta = BN::JSON->read('Delta_en.json');
   while (my ($k,$v) = each %$delta) {
      $text->{$k} = $v;
   }
}

sub get {
   my ($class, $key) = @_;
   return 'none' unless defined $key;
   load_text() unless $text;
   return $text->{lc($key)} // $text->{$key} // $key;
}

sub fetch {
   my ($class, $key) = @_;
   return undef unless defined $key;
   load_text() unless $text;
   return $text->{lc($key)};
}

1 # end BN::Text
