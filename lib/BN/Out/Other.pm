package BN::Out::Other;
use strict;
use warnings;
use Data::Dump qw( dump );

sub write {
   write_hints();
   write_boosts();
}

sub write_hints {
   my $hints = BN::File->json('My_Land_Hint.json');
   my $file = BN::Out->filename('info', 'Loading Screen Statements');
   open my $F, '>', $file or die "Can't write $file: $!\n";

   foreach my $hint (@$hints) {
      my $text = $hint->{text} or next;
      foreach my $line (@$text) {
         my $words = BN::Text->get($line->{body}) or next;
         print $F "'''''$words'''''\n\n";
      }
   }

   close $F;
   BN::Out->checksum($file);
}

sub write_boosts {
   my $boosts = BN::File->json('RewardMultiplierOffers.json');
   my $file = BN::Out->filename('info', 'Boosts');
   open my $F, '>', $file or die "Can't write $file: $!\n";
   print $F dump($boosts);
   close $F;
   BN::Out->checksum($file);
}

1 # end BN::Out::Other
