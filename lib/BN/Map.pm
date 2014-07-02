package BN::Map;
use strict;
use warnings;

my $maps;

sub get {
   my ($class, $key) = @_;
   return unless $key;
   $maps ||= BN::File->json('NPCs.json');
   my $map = $maps->{$key} or return;
   if (ref($map) eq 'HASH') {
      bless $map => $class;
      $map->{_name} = BN::Text->get($map->{name});
   }
   return $map;
}

BN->simple_accessor('name');
BN->simple_accessor(level => 'level');

1 # end BN::Map
