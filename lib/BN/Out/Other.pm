package BN::Out::Other;
use strict;
use warnings;

sub write {
   my $hints = BN::JSON->read('My_Land_Hint.json');
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

1 # end BN::Out::Other
