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
   return BN->format_amount(delete $mis->{rewards});
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

1 # end BN::Mission
