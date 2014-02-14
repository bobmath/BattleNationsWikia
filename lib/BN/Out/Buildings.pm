package BN::Out::Buildings;
use strict;
use warnings;
use BN::Out;
use Data::Dump qw( dump );

sub write {
   mkdir 'buildings';
   mkdir 'other';
   foreach my $build (BN::Building->all()) {
      my $dir = $build->build_menu() ? 'buildings' : 'other';
      my $file = BN::Out->filename($dir, $build->name());
      print $file, "\n";
      open my $F, '>', $file or die "Can't write $file: $!";;
      print $F dump($build), "\n";
   }
}

1 # end BN::Out::Buildings
