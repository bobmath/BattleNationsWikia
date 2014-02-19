package BN::Mission;
use strict;
use warnings;

my $missions;
my $json_file = 'Missions.json';

sub all {
   my ($class) = @_;
   $missions ||= BN::JSON->read($json_file);
   return map { $class->get($_) } sort keys %$missions;
}

sub get {
   my ($class, $key) = @_;
   return unless $key;
   $missions ||= BN::JSON->read($json_file);
   my $mis = $missions->{$key} or return;
   if (ref($mis) eq 'HASH') {
      bless $mis, $class;
      $mis->{_tag} = $key;
      $mis->{_name} = BN::Text->get($mis->{title});
   }
   return $mis;
}

BN->simple_accessor('name');
BN->simple_accessor('tag');
BN->simple_accessor('hidden', 'hideIcon');

sub level {
   my ($mis) = @_;
   return $mis->{_level} if exists $mis->{_level};
   BN::Prereqs->calc_levels();
   return $mis->{_level};
}

sub prereqs {
   my ($mis) = @_;
   my @prereqs;
   foreach my $sec (qw( startRules objectives )) {
      my $rules = $mis->{$sec} or next;
      foreach my $key (sort keys %$rules) {
         my $rule = $rules->{$key} or next;
         my $prereq = $rule->{prereq} or next;
         push @prereqs, $prereq;
      }
   }
   return @prereqs;
}

BN->accessor(rewards => sub {
   my ($mis) = @_;
   my $rewards = delete $mis->{rewards} or return;
   my @rewards;
   if (my $units = delete $rewards->{units}) {
      foreach my $id (keys %$units) {
         my $unit = BN::Unit->get($id) or next;
         my $name = $unit->name() or next;
         $name = "[[$name]]";
         $name .= " x $units->{$id}" if $units->{$id} > 1;
         push @rewards, $name;
      }
      @rewards = sort @rewards;
   }
   push @rewards, BN->format_amount($rewards, 0, ' &nbsp; ');
   return join ' &nbsp; ', @rewards;
});

sub objectives {
   my ($mis) = @_;
   my $objectives = $mis->{objectives} or return;
   my @obj;
   foreach my $key (sort keys %$objectives) {
      my $obj = $objectives->{$key} or next;
      my $prereq = $obj->{prereq} or next;
      push @obj, $prereq;
   }
   return @obj;
}

sub unlocks_buildings {
   my ($mis) = @_;
   if (!exists $mis->{_unlocks_buildings}) {
      $_->{_unlocks_buildings} = undef foreach BN::Mission->all();
      foreach my $bld (BN::Building->all()) {
         foreach my $id ($bld->mission_reqs()) {
            my $m = BN::Mission->get($id) or next;
            push @{$m->{_unlocks_buildings}}, $bld->tag();
         }
      }
   }
   return unless $mis->{_unlocks_buildings};
   return @{$mis->{_unlocks_buildings}};
}

sub unlocks_units {
   my ($mis) = @_;
   if (!exists $mis->{_unlocks_units}) {
      $_->{_unlocks_units} = undef foreach BN::Mission->all();
      foreach my $unit (BN::Unit->all()) {
         foreach my $id ($unit->mission_reqs()) {
            my $m = BN::Mission->get($id) or next;
            push @{$m->{_unlocks_units}}, $unit->tag();
         }
      }
   }
   return unless $mis->{_unlocks_units};
   return @{$mis->{_unlocks_units}};
}

1 # end BN::Mission
