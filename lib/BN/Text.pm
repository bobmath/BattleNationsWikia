package BN::Text;
use strict;
use warnings;

my $text;

sub load_text {
   return if $text;
   $text = BN::File->json('BattleNations_en.json');
   my $delta = BN::File->json('Delta_en.json');
   while (my ($k,$v) = each %$delta) {
      $text->{$k} = $v;
   }
}

sub get {
   my ($class, $key) = @_;
   return undef unless defined $key;
   load_text() unless $text;
   return $text->{lc($key)};
}

sub get_all {
   load_text() unless $text;
   return $text;
}

1 # end BN::Text
