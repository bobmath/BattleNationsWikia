package BN::Building;
use strict;
use warnings;

my $buildings;
my $json_file = 'Compositions.json';

sub all {
   my ($class) = @_;
   $buildings ||= BN::JSON->read($json_file);
   return map { $class->get($_) } sort keys %$buildings;
}

sub get {
   my ($class, $key) = @_;
   $buildings ||= BN::JSON->read($json_file);
   my $build = $buildings->{$key} or return;
   if (ref($build) eq 'HASH') {
      bless $build, $class;
      $build->{_tag} = $key;
      if (my $configs = delete $build->{componentConfigs}) {
         while (my ($k,$v) = each %$configs) {
            $build->{$k} = $v;
         }
      }
      if (my $struct = $build->{StructureMenu}) {
         $build->{_name} = BN::Text->get($struct->{name});
      }
      else {
         $build->{_name} = 'noname';
      }
   }
   return $build;
}

BN->simple_accessor('tag');
BN->simple_accessor('name');

sub units {
   my ($build) = @_;
   my $projects = $build->{ProjectList} or return;
   my $jobs = $projects->{jobs} or return;
   return @$jobs;
}

sub level {
   my ($build) = @_;
   return $build->{_level} if exists $build->{_level};
   BN::Prereqs->calc_levels();
   return $build->{_level};
}

sub prereqs {
   my ($build) = @_;
   my $structure = $build->{StructureMenu} or return;
   my $prereqs = $structure->{prereq} or return;
   return map { $prereqs->{$_} } sort keys %$prereqs;
}

my %build_cats = (
   bmCat_houses => 'Housing',
   bmCat_shops  => 'Shops',
   bmCat_military => 'Military',
   bmCat_resources => 'Resources',
   bmCat_decorations => 'Decorations',
);

sub build_menu {
   my ($build) = @_;
   return $build->{_build_menu} if exists $build->{_build_menu};

   my $buildable = BN::JSON->read('StructureMenu.json');

   foreach my $b (BN::Building->all()) {
      $b->{_build_menu} = undef;
   }

   foreach my $group (@$buildable) {
      my $cat = $build_cats{$group->{title}} or next;
      foreach my $tag (@{$group->{options}}) {
         my $build = BN::Building->get($tag) or next;
         $build->{_build_menu} = $cat;
      }
   }

   return $build->{_build_menu};
}

1 # end BN::Building
