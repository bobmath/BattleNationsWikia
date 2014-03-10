package BN::Out::Guilds;
use strict;
use warnings;

sub write {
   my $guilds = BN::File->json('GuildConfig.json');
   my $file = BN::Out->filename('info', 'Guilds');
   open my $F, '>', $file or die "Can't write $file: $!";

   print $F qq({| class="wikitable standout"\n);
   print $F "|-\n! Guild Level !! Member Limit !! XP Bonus !! SP Bonus\n";
   my $levels = $guilds->{guildLevelProperties} or die;
   foreach my $lev (sort { $a <=> $b } keys %$levels) {
      my $level = $levels->{$lev} or die;
      print $F qq(|- align="center"\n! $lev\n);
      print $F "| $level->{memberCap} || $level->{xpBoost}% ",
         "|| $level->{spBoost}%\n";
   }
   print $F "|}\n";

   close $F;
   BN::Out->checksum($file);
}

1 # end BN::Out::Guilds
