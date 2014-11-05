package BN::Out::Guilds;
use strict;
use warnings;
use Data::Dump qw( dump );

sub write {
   my $guilds = BN::File->json('GuildConfig.json');
   my $file = BN::Out->filename('info', 'Guilds');
   open my $F, '>', $file or die "Can't write $file: $!";

   print $F qq({| class="wikitable standout"\n);
   print $F "|-\n! Guild Level !! {{Gold}} Gold Required !! ",
      "{{Gold}} Total Gold !! ",
      "[[File:BN_icon_friendsGuilds.png|20px]] Member Limit !! ",
      "{{XP}} XP Bonus !! {{SP}} SP Bonus\n";
   my $levels = $guilds->{guildLevelProperties} or die;
   my $prev_gold = 0;
   foreach my $lev (sort { $a <=> $b } keys %$levels) {
      my $level = $levels->{$lev} or die;
      my $gold = $level->{xpRequirement};
      print $F qq(|- align="center"\n! $lev\n);
      print $F "| ", BN->commify($gold - $prev_gold), " || ",
         BN->commify($gold), " || $level->{memberCap} || ",
         "$level->{xpBoost}% || $level->{spBoost}%\n";
      $prev_gold = $gold;
   }
   print $F "|}\n\n";

   print $F dump($guilds);
   close $F;
   BN::Out->compare($file);
}

1 # end BN::Out::Guilds
