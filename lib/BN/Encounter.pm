package BN::Encounter;
use strict;
use warnings;

my $encounters;

sub get {
   my ($class, $key) = @_;
   return unless $key;
   $encounters ||= BN::JSON->read('BattleEncounters.json');
   my $enc = $encounters->{armies}{$key} or return;
   if (ref($enc) eq 'HASH') {
      bless $enc, $class;
   }
   return $enc;
}

BN->accessor(rewards => sub {
   my ($enc) = @_;
   return BN->flatten_amount(delete $enc->{rewards});
});

1 # end BN::Encounter
