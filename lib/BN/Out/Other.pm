package BN::Out::Other;
use strict;
use warnings;
use Data::Dump qw( dump );

sub write {
   write_hints();
   write_text();
   write_economy();
   write_json('Boosts', 'RewardMultiplierOffers.json');
   write_json('Status Effects',
      'StatusEffectFamiliesConfig.json', 'StatusEffectsConfig.json');
   write_json('Manifest', 'z2manifest.json', 'onDemandOtaManifest.json',
      'onDemandOtaFilenamesByTag.json', 'onDemandOtaTagsByFilename.json');
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

sub write_text {
   my $file = BN::Out->filename('info', 'Text');
   open my $F, '>', $file or die "Can't write $file: $!\n";
   print $F dump(BN::Text::get_all()), "\n";
   close $F;
   BN::Out->checksum($file);
}

sub write_economy {
   my $file = BN::Out->filename('info', 'Economy');
   open my $F, '>', $file or die "Can't write $file: $!\n";
   print $F dump($BN::Job::economy), "\n";
   close $F;
   BN::Out->checksum($file);
}

sub write_json {
   my ($out, @in) = @_;
   my $file = BN::Out->filename('info', $out);
   open my $F, '>', $file or die "Can't write $file: $!\n";
   foreach my $in (@in) {
      my $json = BN::File->json($in);
      print $F dump($json), "\n";
   }
   close $F;
   BN::Out->checksum($file);
}

1 # end BN::Out::Other
