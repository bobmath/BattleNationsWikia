package BN::Encounter;
use strict;
use warnings;

my $json_file = 'BattleEncounters.json';
my $encounters;

sub all {
   my ($class) = @_;
   $encounters ||= BN::File->json($json_file);
   return map { $class->get($_) } sort grep { !/^test/ }
      keys %{$encounters->{armies}};
}

sub get {
   my ($class, $key) = @_;
   return unless $key;
   $encounters ||= BN::File->json($json_file);
   my $enc = $encounters->{armies}{$key} or return;
   if (ref($enc) eq 'HASH') {
      bless $enc, $class;
      $enc->{_tag} = $key;
   }
   return $enc;
}

BN->simple_accessor('tag');
BN->simple_accessor('level', 'level');

BN->accessor(rewards => sub {
   my ($enc) = @_;
   return BN->flatten_amount(delete $enc->{rewards});
});

BN->list_accessor(unit_ids => sub {
   my ($enc) = @_;
   my $units = $enc->{units} or return;
   my %units;
   foreach my $unit (@$units) {
      my $id = $unit->{unitId} or next;
      $units{$id} = 1;
   }
   return sort keys %units;
});

my %tables;
sub tables {
   my ($enc) = @_;
   if (!%tables) {
      foreach my $key (sort keys %{$encounters->{tables}}) {
         my $table = $encounters->{tables}{$key};
         foreach my $inf (@{$table->{encounters}}) {
            push @{$tables{$inf->{encounterId}}}, $key;
         }
      }
   }
   my $tbls = $tables{$enc->tag()} or return;
   return @$tbls;
}

1 # end BN::Encounter
