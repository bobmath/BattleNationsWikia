package BN::Job;
use strict;
use warnings;

my $jobs;

sub get {
   my ($class, $key) = @_;
   return unless $key;
   $jobs ||= BN::File->json('JobInfo.json');
   my $job = $jobs->{jobs}{$key} or return;
   if (ref($job) eq 'HASH') {
      bless $job => $class;
      $job->{_tag} = $key;
      $job->{_name} = BN::Text->get($job->{name}) || $key;
   }
   return $job;
}

BN->simple_accessor('tag');
BN->simple_accessor('name');
BN->simple_accessor('icon', 'icon');
BN->simple_accessor('building_level', 'buildingLevel');

BN->list_accessor(missions => sub {
   my ($job) = @_;
   my $prereqs = $job->{prereq} or return;
   foreach my $key (sort keys %$prereqs) {
      my $prereq = $prereqs->{$key} or next;
      my $t = $prereq->{_t} or next;
      next unless $t eq 'ActiveMissionPrereqConfig';
      next unless $prereq->{missionActive};
      my $ids = $prereq->{missionIds} or next;
      return @$ids;
   }
   return;
});

sub buildings {
   my ($job) = @_;
   unless (exists $job->{_buildings}) {
      $_->{_buildings} = undef foreach values %$jobs;
      foreach my $build (BN::Building->all()) {
         foreach my $j ($build->jobs(), $build->quest_jobs()) {
            push @{$j->{_buildings}}, $build->tag();
         }
      }
   }
   return unless $job->{_buildings};
   return @{$job->{_buildings}};
}

BN->accessor(cost => sub {
   my ($job) = @_;
   return BN->flatten_amount(delete($job->{cost}), delete($job->{buildTime}));
});

BN->accessor(rewards => sub {
   my ($job) = @_;
   return BN->flatten_amount(delete($job->{rewards}));
});

our $economy;
sub demand_cat {
   my ($job) = @_;
   if (!$economy) {
      $economy = BN::File->json('Economy.json');
      my $families = $economy->{families} or die;
      foreach my $cat (sort keys %$families) {
         my $info = $families->{$cat} or die;
         my $jobs = delete $info->{jobs} or next;
         next if $cat eq 'Fake';
         foreach my $id (@$jobs) {
            my $job = BN::Job->get($id) or next;
            die "multiple cats for $id" if $job->{_demand_cat};
            $job->{_demand_cat} = $cat;
         }
      }
   }
   return $job->{_demand_cat};
}

1 # end BN::Job
