package BN::Out::Missions;
use strict;
use warnings;
use BN::Out;
use Data::Dump qw( dump );

my ($curr_lo, $curr_hi);

sub write {
   $curr_hi = 0;
   my $max = BN::Level->max();
   my $F;
   foreach my $mis (
      sort { $a->level() <=> $b->level() || $a->name() cmp $b->name() }
      grep { $_->level() } BN::Mission->all())
   {
      if ($mis->level() > $curr_hi) {
         $curr_hi = int(($mis->level() + 9) / 10) * 10;
         $curr_lo = $curr_hi - 9;
         if ($curr_hi > $max && $curr_lo <= $max) {
            $curr_hi = $max;
         }
         my $file = BN::Out->filename('missions',
            "Level $curr_lo-$curr_hi missions");
         open $F, '>:utf8', $file or die "Can't write $file: $!";
      }
      show_mission($F, $mis);
   }
   close $F;

#   foreach my $mis (BN::Mission->all()) {
#      my $file = BN::Out->filename('missions', $mis->level(), $mis->name());
#      print $file, "\n";
#      open $F, '>:utf8', $file or die "Can't write $file: $!";;
#      print $F dump($mis), "\n";
#      close $F;
#      BN::Out->checksum($file);
#   }
}

my %seen;
sub show_mission {
   my ($F, $mis) = @_;
   return unless $mis;
   return if $seen{$mis->tag()}++;

   my @prereqs = $mis->min_prereqs();
   show_mission($F, BN::Mission->get($_)) foreach @prereqs;

   print $F "===", $mis->name(), "===\n",
      "{{MissionInfo\n";
   print_line($F, 'level', $mis->level());

   if (@prereqs) {
      print_line($F, 'prereq', join(', ', map { mission_link($_) } @prereqs));
   }

   if (my $desc = $mis->description_script()) {
      $desc = $desc->[0];
      if (my $who = $desc->{speaker}) {
         print_line($F, 'image', "{{\u${who}Image|150x120px}}");
      }
      if (my $text = $desc->{text}) {
         print_line($F, 'desc', $text->[0]{_body});
      }
   }

   my @rewards;
   if (my $rewards = $mis->rewards()) {
      push @rewards, BN->format_amount($rewards, 0, ', ');
   }
   foreach my $unl ($mis->unlocks_buildings(), $mis->unlocks_units()) {
      push @rewards, 'unlocks ' . $unl->wikilink();
   }
   print_line($F, 'reward', join(', ', @rewards)) if @rewards;

   my @followups = $mis->followups();
   if (@followups) {
      print_line($F, 'followup',
         join(', ', map { mission_link($_) } @followups));
   }

   my $n;
   foreach my $obj ($mis->objectives()) {
      my $tag = 'goal' . ++$n;
      print_line($F, $tag, $obj->text());
      print_line($F, $tag.'image', BN::Out->icon($obj->icon(),
         "40x40px|link=" . $obj->link()));
   }

   print_line($F, 'game file name', $mis->tag());
   print $F "}}\n\n";

   if (@followups == 1) {
      if (my $follow = BN::Mission->get($followups[0])) {
         my $lev = $follow->level() || 0;
         if ($lev >= $curr_lo && $lev <= $curr_hi) {
            my @pre = $follow->min_prereqs();
            show_mission($F, $follow) if @pre == 1;
         }
      }
   }
}

sub print_line {
   my ($F, $tag, $val) = @_;
   printf $F "| %-14s = %s\n", $tag, $val if defined $val;
}

sub mission_link {
   my ($mis) = @_;
   return unless $mis;
   if (!ref $mis) {
      $mis = BN::Mission->get($mis) or return;
   }
   my $lev = $mis->level() || 0;
   if ($lev >= $curr_lo && $lev <= $curr_hi) {
      my $name = $mis->name();
      return "[[#$name|$name]]";
   }
   return $mis->wikilink();
}

1 # end BN::Out::Missions
