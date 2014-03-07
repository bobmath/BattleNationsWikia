package BN::Encounter;
use strict;
use warnings;

my $json_file = 'BattleEncounters.json';
my $encounters;

sub all {
   my ($class) = @_;
   $encounters ||= BN::JSON->read($json_file);
   return map { $class->get($_) } sort keys %{$encounters->{armies}};
}

sub get {
   my ($class, $key) = @_;
   return unless $key;
   $encounters ||= BN::JSON->read($json_file);
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

BN->list_accessor(units => sub {
   my ($enc) = @_;
   my $units = $enc->{units} or return;
   my %units;
   foreach my $unit (@$units) {
      my $id = $unit->{unitId} or next;
      $units{$id} = 1;
   }
   return sort keys %units;
});

sub tables {
   my ($enc) = @_;
   if (!exists $enc->{z_tables}) {
      $_->{z_tables} = undef foreach BN::Encounter->all();
      foreach my $key (sort keys %{$encounters->{tables}}) {
         my $table = $encounters->{tables}{$key};
         foreach my $inf (@{$table->{encounters}}) {
            my $e = BN::Encounter->get($inf->{encounterId}) or next;
            push @{$e->{z_tables}}, $key;
         }
      }
   }
   return unless $enc->{z_tables};
   return @{$enc->{z_tables}};
}

1 # end BN::Encounter
