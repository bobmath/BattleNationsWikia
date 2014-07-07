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
         $curr_hi = int(($mis->level() + 4) / 5) * 5;
         $curr_lo = $curr_hi - 4;
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

   foreach my $mis (BN::Mission->all()) {
      my $file = BN::Out->filename('missions', $mis->level(), $mis->name());
      print $file, "\n";
      open $F, '>:utf8', $file or die "Can't write $file: $!";;
      print $F dump($mis), "\n";
      close $F;
      BN::Out->checksum($file);
   }
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
   my (%cost, %time);
   foreach my $obj ($mis->objectives()) {
      my $tag = 'goal' . ++$n;
      print_line($F, $tag, $obj->text());
      print_line($F, $tag.'image', BN::Out->icon($obj->icon(),
         "40x40px|link=" . $obj->link()));
      if (my $cost = $obj->cost()) {
         while (my ($k,$v) = each %$cost) {
            $cost{$k} += $v;
         }
      }
      if ((my $tag = $obj->timetag()) && (my $time = $obj->time())) {
         $time{$tag} += $time;
      }
   }
   if (%cost || %time) {
      my $time = 0;
      foreach my $t (values %time) {
         $time = $t if $t > $time;
      }
      print_line($F, 'notes', BN->format_amount(\%cost, $time, ', '));
   }

   print_line($F, 'game file name', $mis->tag());
   print $F "}}\n";

   @rewards = ();
   foreach my $enc ($mis->encounters()) {
      my $rewards = $enc->rewards() or next;
      push @rewards, BN->format_amount($rewards, 0, ', ');
   }
   if (@rewards == 1) {
      print $F "Encounter reward: @rewards\n\n";
   }
   elsif (@rewards) {
      print $F "Encounter rewards:\n";
      print $F "* $_\n" foreach @rewards;
      print $F "\n";
   }

   my $first = 1;
   show_script($F, $mis->start_script(), 'Start mission', \$first);
   show_script($F, $mis->finish_script(), 'Finish mission', \$first);
   show_script($F, $mis->reward_script(), 'Reward screen', \$first);
   print $F "|}\n" unless $first;
   print $F "\n";

   if (my $follow = get_single(@followups)) {
      show_mission($F, $follow) if get_single($follow->min_prereqs());
   }
}

sub get_single {
   my @list;
   foreach my $id (@_) {
      my $mis = BN::Mission->get($id) or next;
      my $lev = $mis->level() or next;
      push @list, $mis if $lev >= $curr_lo && $lev <= $curr_hi;
   }
   return unless @list == 1;
   return $list[0];
}

sub show_script {
   my ($F, $script, $label, $first) = @_;
   return unless $script;
   if ($$first) {
      print $F qq[{| class="mw-collapsible mw-collapsed"\n],
         qq[|-\n],
         qq[! colspan="2" | Dialogue\n];
      $$first = 0;
   }

   print $F qq[|-\n],
      qq[! colspan="2" align="left" | $label\n];

   foreach my $elem (@$script) {
      my $who = $elem->{speaker} // '';
      $who = '{{' . ucfirst($who) . 'Image}}' if $who;
      my @text;
      foreach my $text (@{$elem->{text}}) {
         if (my $t = $text->{_title}) {
            push @text, "'''$t'''";
         }
         if (my $t = $text->{_body}) {
            push @text, $t;
         }
      }
      print $F qq[|- valign="top"\n| $who || ], join('<br>', @text), "\n";
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
