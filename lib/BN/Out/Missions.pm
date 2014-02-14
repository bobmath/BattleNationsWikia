package BN::Out::Missions;
use strict;
use warnings;
use BN::Out;
use Data::Dump qw( dump );

sub write {
   mkdir 'missions';
   mkdir "missions/$_" for 0 .. 66;

   foreach my $mis (BN::Mission->all()) {
      my $level = $mis->level() || 0;
      my $file = BN::Out->filename($mis->name(), "missions/$level");
      print $file, "\n";
      open my $F, '>', $file or die "Can't write $file: $!";;
      print $F dump($mis), "\n";
   }
}

1 # end BN::Out::Missions
