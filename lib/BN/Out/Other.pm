package BN::Out::Other;
use strict;
use warnings;
use Data::Dump qw( dump );

sub write {
   write_land();
   write_text();
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
   BN::Out->compare($file);
}

sub write_text {
   my $file = BN::Out->filename('info', 'Text');
   open my $F, '>', $file or die "Can't write $file: $!\n";
   print $F dump(BN::Text::get_all()), "\n";
   close $F;
   BN::Out->compare($file);
}

1 # end BN::Out::Other
