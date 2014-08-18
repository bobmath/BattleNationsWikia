package BN::Out::Other;
use strict;
use warnings;
use Data::Dump qw( dump );

sub write {
   write_hints();
   write_text();
   write_economy();
   write_land();
   write_encounters();
   write_json('Boosts', 'RewardMultiplierOffers.json');
   write_json('Exclude', 'ExcludeTags.json');
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

sub write_land {
   my $expand = BN::File->json('ExpandLandCosts.json');
   my $file = BN::Out->filename('info', 'Land_Expansion_Chart');
   open my $F, '>', $file or die "Can't write $file: $!";
   print $F qq[{| class="wikitable standout"\n|-\n],
      "! Level !! Cost !! Build Time !! Total\n";

   my $n = 4;
   for my $exp (@$expand) {
      ++$n;
      my $level = $exp->{prereq}{1}{level} or die;
      my $money = BN->commify($exp->{moneyCost}{money}) or die;
      my $nanos = $exp->{currencyCost}{currency} or die;
      my $time  = BN->format_time($exp->{buildTime}) or die;
      print $F qq[|- align="center"\n! $level\n],
         "| {{Gold|$money}} or {{Nanopods|$nanos}} ||{{Time|$time}} || $n\n";
   }

   print $F "|}\n";
   close $F;
   BN::Out->checksum($file);
}

sub write_encounters {
   my $file = BN::Out->filename('info', 'Encounters');
   open my $F, '>', $file or die "Can't write $file: $!\n";
   foreach my $enc (BN::Encounter->all()) {
      print $F $enc->tag(), "\n", dump($enc), "\n\n";
   }
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
