package BN::Out::Missions;
use strict;
use warnings;
use BN::Out;
use Data::Dump qw( dump );

sub write {
   level_pages();
   index_page();
   mission_pages();
}

my $curr_page;

sub level_pages {
   my %pages;
   foreach my $mis (BN::Mission->all()) {
      $pages{$mis->wikipage()}{$mis->tag()} = $mis;
   }
   foreach my $page (sort keys %pages) {
      $curr_page = $pages{$page} or die;
      my $file = BN::Out->filename('missions', $page);
      open my $F, '>:utf8', $file or die "Can't write $file: $!";
      foreach my $mis (sort { ($a->level()||0) <=> ($b->level()||0)
         || $a->name() cmp $b->name() } values %$curr_page)
      {
         show_mission($F, $mis);
      }
      close $F;
      BN::Out->compare($file);
   }
}

sub index_page {
   my %index;
   foreach my $mis (BN::Mission->all()) {
      next if $mis->hidden() || $mis->is_promo();
      my $level = $mis->level() or next;
      my $name = lc($mis->name());
      $name =~ s/^an?\s+|^the\s+//;
      $name =~ s/^\W+//;
      $name =~ s/^(\d)/#$1/;
      $name =~ s/(\d+)/sprintf '%4d', $1/eg;
      $index{uc(substr($name,0,1))}{$name}{$level} = $mis->wikilink();
   }

   my $file = BN::Out->filename('missions', 'Mission_index');
   open my $F, '>:utf8', $file or die "Can't write $file: $!";

   foreach my $key (sort keys %index) {
      my $sec = $index{$key} or next;
      my @col1;
      foreach my $nm (sort keys %$sec) {
         my $missions = $sec->{$nm} or next;
         if (keys(%$missions)  <= 1) {
            push @col1, values %$missions;
         }
         else {
            foreach my $lvl (sort { $a <=> $b } keys %$missions) {
               push @col1, "$missions->{$lvl} ($lvl)";
            }
         }
      }

      my @col2 = splice @col1, (@col1+1)/2;
      print $F "==$key==\n{{Col-begin}}\n";
      print $F "* $_\n" foreach @col1;
      print $F "{{Col-2}}";
      print $F "* $_\n" foreach @col2;
      print $F "{{Col-end}}\n\n";
   }

   close $F;
   BN::Out->compare($file);
}

sub mission_pages {
   foreach my $mis (BN::Mission->all()) {
      my $file = BN::Out->filename('missions', 'all', $mis->tag());
      open my $F, '>:utf8', $file or die "Can't write $file: $!";;
      print $F dump($mis), "\n";
      close $F;
      BN::Out->compare($file);
   }
}

my %seen;
sub show_mission {
   my ($F, $mis) = @_;
   return unless $mis;
   return if $seen{$mis->tag()}++;

   my @prereqs = $mis->min_prereqs();
   foreach my $id (@prereqs) {
      show_mission($F, BN::Mission->get($id)) if $curr_page->{$id};
   }

   print $F "===", $mis->name(), "===\n",
      "{{MissionInfo\n";
   print_line($F, 'level', $mis->level());

   if (@prereqs) {
      print_line($F, 'prereq', mission_links(@prereqs));
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
      print_line($F, 'followup', mission_links(@followups));
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
      print_line($F, 'cost', BN->format_amount(\%cost, $time, ', '));
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
      next unless $curr_page->{$id};
      push @list, BN::Mission->get($id);
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
      print $F qq[|- valign="top"\n| align="center" | $who\n| ],
         join('<br>', @text), "\n";
   }
}

sub print_line {
   my ($F, $tag, $val) = @_;
   printf $F "| %-14s = %s\n", $tag, $val if defined $val;
}

sub mission_links {
   my @mis;
   foreach my $m (@_) {
      push @mis, ref($m) ? $m : BN::Mission->get($m);
   }
   @mis = sort { ($a->level() || 0) <=> ($b->level() || 0)
      || $a->name() cmp $b->name() } @mis;
   my @out;
   foreach my $mis (@mis) {
      if ($curr_page->{$mis->tag()}) {
         my $name = $mis->name();
         push @out, "[[#$name|$name]]";
      }
      else {
         push @out, $mis->wikilink();
      }
   }
   return join ', ', @out;
}

1 # end BN::Out::Missions
