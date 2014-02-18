package BN::Out::Missions;
use strict;
use warnings;
use BN::Out;
use Data::Dump qw( dump );

sub write {
   mkdir 'missions';
   mkdir 'missions/_';
   mkdir "missions/$_" for 1 .. 71;
   foreach my $mis (BN::Mission->all()) {
      my $file = BN::Out->filename('missions', $mis->level(), $mis->name());
      print $file, "\n";
      open my $F, '>', $file or die "Can't write $file: $!";;
      print $F dump($mis), "\n";
   }
}

1 # end BN::Out::Missions
