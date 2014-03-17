package BN::Out::Guilds;
use strict;
use warnings;
use Data::Dump qw( dump );

sub write {
   my $guilds = BN::File->json('GuildConfig.json');
   my $file = BN::Out->filename('info', 'Guilds');
   open my $F, '>', $file or die "Can't write $file: $!";

   print $F qq({| class="wikitable standout"\n);
   print $F "|-\n! Guild Level !! XP Required !! Member Limit",
      " !! XP Bonus !! SP Bonus\n";
   my $levels = $guilds->{guildLevelProperties} or die;
   foreach my $lev (sort { $a <=> $b } keys %$levels) {
      my $level = $levels->{$lev} or die;
      my $xp = BN->commify($level->{xpRequirement});
      print $F qq(|- align="center"\n! $lev\n);
      print $F "| $xp || $level->{memberCap} || $level->{xpBoost}% ",
         "|| $level->{spBoost}%\n";
   }
   print $F "|}\n\n";

   print $F dump($guilds);
   close $F;
   BN::Out->checksum($file);
}

1 # end BN::Out::Guilds
