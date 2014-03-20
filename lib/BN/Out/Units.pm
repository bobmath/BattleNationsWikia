package BN::Out::Units;
use strict;
use warnings;
use Data::Dump qw( dump );

sub write {
   my %enemies;
   foreach my $unit (BN::Unit->all()) {
      my $side = $unit->side() // '';
      my $dir;
      if ($side eq 'Player') {
         $dir = $unit->building() || $unit->from_missions()
               || $unit->boss_strike() ? 'units' : 'locked';
      }
      elsif ($side eq 'Hostile') {
         if ($unit->level()) {
            my $name = $unit->name();
            if ($name =~ /^Specimen [a-h]\d+ ['"](.+)['"]$/) {
               $name = $1;
               $name =~ s/^(?:Proto-|Advanced|Archetype)\s*//;
            }
            push @{$enemies{$name}}, $unit;
            next;
         }
         $dir = 'other';
      }
      else {
         $dir = 'other';
      }
      my $file = BN::Out->filename($dir, $unit->name());
      print $file, "\n";
      open my $F, '>', $file or die "Can't write $file: $!";;

      unit_profile($F, $unit);
      unit_weapons($F, $unit);
      unit_ranks($F, $unit);
      unit_cost($F, $unit);
      print $F dump($unit), "\n";
      close $F;
      BN::Out->checksum($file);
   }

   foreach my $name (sort keys %enemies) {
      my $units = $enemies{$name} or die;
      @$units = sort {$a->level() <=> $b->level()} @$units;
      my $file = BN::Out->filename('enemies', $name);
      print $file, "\n";
      open my $F, '>', $file or die "Can't write $file: $!";

      my $unit = $units->[0];
      my $affil = guess_affil($unit);
      if ($name eq $unit->name()) {
         $name = $unit->enemy_name();
      }
      else {
         $name .= ' (enemy)';
      }
      print $F $name, "\n";

      enemy_profile($F, $units, $affil);
      enemy_defense($F, $units);
      enemy_attacks($F, $units, $affil);

      print $F "\n", dump($units), "\n";
      close $F;
      BN::Out->checksum($file);
   }
}

my %train_map = (
   comp_milUnit_animalTrainer    => 'animal trainer',
   comp_milUnit_barracks         => 'barracks',
   comp_milUnit_bigfootSchool    => 'bigfoot training',
   comp_milUnit_frontierBarracks => 'frontier recruit',
   comp_milUnit_laserbarracks    => 'optics facility',
   comp_milUnit_raiderbarracks   => 'raider training',
   comp_milUnit_silverWolves     => 'mercenary vault',
   comp_milUnit_vehiclefactory   => 'vehicle factory',
);

sub unit_profile {
   my ($F, $unit) = @_;
   print $F $unit->name(), "\n";
   print $F "{{UnitProfile\n";
   profile_line($F, 'image', BN::Out->icon($unit->icon()));
   if (my $short = $unit->shortname()) {
      profile_line($F, 'shortname', $short) unless $short eq $unit->name();
   }
   profile_line($F, 'unit type', $unit->type());
   profile_line($F, 'unit level', $unit->level());
   if (my $build = $unit->building()) {
      my $name = $train_map{$build};
      profile_line($F, "$name level", $unit->building_level() || 1) if $name;
   }
   profile_line($F, 'other requirements', $unit->other_reqs());
   profile_line($F, 'immunities', $unit->immunities());
   profile_line($F, 'blocking', $unit->blocking());

   my @notes;
   if (my ($rank) = $unit->ranks()) {
      if ($unit->max_armor()) {
         damage_mods($F, 'armor', $rank->armor_mods());
         if (my $type = $rank->armor_type()) {
            push @notes, 'No armor while stunned' if $type eq 'active';
         }
      }
      damage_mods($F, 'base', $rank->damage_mods());
   }
   if (my $limit = $unit->deploy_limit()) {
      push @notes, "Deployment limit: $limit";
   }

   profile_line($F, 'notes', join('<br>', @notes)) if @notes;
   profile_line($F, 'game file name', $unit->tag());
   print $F "}}\n";
   if (my $desc = $unit->description()) {
      print $F "{{IGD|$desc}}\n";
   }
   print $F "==Overview==\n{{Clear}}\n\n";
}

sub damage_mods {
   my ($F, $tag, $mods) = @_;
   foreach my $key (sort keys %$mods) {
      my $val = $mods->{$key};
      profile_line($F, join('_', $tag, lc($key), 'defense'), $val*100)
         unless $val == 1;
   }
}

sub profile_line {
   my ($F, $tag, $val) = @_;
   printf $F "| %-23s = %s\n", $tag, $val if defined $val;
}

sub unit_weapons {
   my ($F, $unit) = @_;
   my $first = 1;
   my $attackbox = $unit->ranks() > 6 ? 'Attack9BoxTabber' : 'AttackBoxTabber';
   foreach my $weap ($unit->weapons()) {
      print $F $first ? "==Attacks==\n<tabber>\n" : "|-|\n";
      $first = 0;
      print $F $weap->name(), "=\n";
      print $F "{{WeaponBoxTabber\n";
      print_line($F, 'game file name', $weap->tag());
      print_line($F, 'ammo', $weap->ammo());
      print_line($F, 'reload', $weap->reload());
      my @attacks = $weap->attacks();
      my $nattacks = $unit->max_ability_slots();
      $nattacks = @attacks if @attacks < $nattacks;
      my $n;
      foreach my $attack (@attacks) {
         my $rank = $attack->rank();
         my $r = 1;
         print_line($F, 'attack' . ++$n, '');
         print $F "{{$attackbox\n";
         print_line($F, 'name', $attack->name());
         print_line($F, 'weaponicon', BN::Out->icon($attack->icon(), '40px'));
         $r += print_line($F, 'rank', $rank);
         $r += print_line($F, 'damagetype', $attack->dmgtype());
         print_line($F, 'mindmg', $attack->mindmg());
         print_line($F, 'maxdmg', $attack->maxdmg());
         print_line($F, 'numattacks', $attack->numattacks());
         print_line($F, 'baseoffense', $attack->offense());
         $r += print_line($F, 'ammoused', $attack->ammoused());
         $r += print_line($F, 'range', $attack->range());
         $r += print_line($F, 'lof', $attack->lof());
         $r += print_line($F, 'cooldown', $attack->cooldown() || undef);
         $r += print_line($F, 'globalcooldown',
            $attack->globalcooldown() || undef) if $nattacks > 1;
         $r += print_line($F, 'preptime', $attack->preptime() || undef);
         $r += print_line($F, 'crit', $attack->crit(0, $unit->max_crit()));
         $r += print_line($F, 'armorpiercing', $attack->armorpiercing());
         $r += print_line($F, 'effects', $attack->effects());
         print_line($F, 'dot', $attack->dot());
         print_line($F, 'dotduration', $attack->dotduration());
         print_line($F, 'dottype', $attack->dottype());
         $r += print_line($F, 'cost', $attack->cost());
         if (my $targ = $attack->targets()) {
            print_line($F, 'targets', $targ);
            print_line($F, 'targetbox-rows', $r) if $r > 7;
         }
         if (my $mods = $attack->rank_mods($unit)) {
            foreach my $key (sort keys %$mods) {
               print_line($F, $key, $mods->{$key});
            }
         }
         print_line($F, 'notes', $attack->notes());
         print_line($F, 'game file name', $attack->tag());
         print $F "}}\n";
      }
      print $F "}}\n";
   }
   print $F "</tabber>\n{{Clear}}\n\n" unless $first;
}

sub unit_ranks {
   my ($F, $unit) = @_;
   my @ranks = $unit->ranks() or return;
   my @ranks1 = @ranks[0 .. $#ranks-1];
   print $F "==Statistics==\n{{",
      (@ranks > 6 ? 'UnitRanks9Box' : 'UnitRanksBox') ,"\n";
   print_ranks($F, 'sp', undef, map { BN->commify($_->sp()) } @ranks1);
   print_ranks($F, 'hp', map { $_->hp() } @ranks);
   print_ranks_opt($F, 'armor', map { $_->armor() } @ranks);
   print_ranks($F, 'bravery', map { $_->bravery() } @ranks);
   print_ranks($F, 'defense', map { $_->defense() } @ranks);
   print_ranks_opt($F, 'dodge', map { $_->dodge() } @ranks);

   damage_mod_ranks($F, 'armormod', map { $_->armor_mods() } @ranks)
      if $unit->max_armor();
   damage_mod_ranks($F, 'damagemod', map { $_->damage_mods() } @ranks);

   if ((my $max = $unit->total_attacks()) > 1) {
      my $n;
      foreach my $rank (@ranks) {
         my $slots = $rank->ability_slots() or next;
         $slots = $max if $slots > $max;
         print_line($F, 'ability' . ++$n, $slots);
      }
   }

   print_ranks_opt($F, 'crit', map { $_->crit() } @ranks)
      if $unit->total_attacks();

   print_ranks($F, 'pc', undef, map { $_->cost() } @ranks1);
   print_ranks($F, 'uv', map { $_->uv() } @ranks);

   my $n;
   foreach my $rank (@ranks) {
      ++$n;
      my $sp = $rank->sp_reward();
      print_line($F, 'spreward' . $n, $sp)
         unless $sp == $rank->uv() * 4;
   }

   $n = 0;
   foreach my $rank (@ranks) {
      ++$n;
      my $gold = $rank->gold_reward();
      print_line($F, 'goldreward' . $n, $gold)
         unless $gold == $rank->uv() * 20;
   }

   my @reqs = map { $_->level_req() } @ranks;
   if (any(@reqs)) {
      $reqs[0] ||= 'N/A';
      $n = 0;
      print_line($F, 'levelreq' . ++$n, $_) foreach @reqs;
   }

   @reqs = map { $_->prerank_req() } @ranks;
   if (any(@reqs)) {
      $reqs[0] ||= 'N/A';
      $n = 0;
      print_line($F, 'prerankreq' . ++$n, $_) foreach @reqs;
   }

   print $F "}}\n\n";
}

sub damage_mod_ranks {
   my ($F, $tag, @mods) = @_;
   my $first = $mods[0];
   my %diff;
   foreach my $mod (@mods[1 .. $#mods]) {
      while (my ($key,$val) = each %$mod) {
         $diff{$key} = 1 if $first->{$key} != $val;
      }
   }
   my @diff = sort keys %diff or return;
   my $n;
   foreach my $mod (@mods) {
      print_line($F, $tag . ++$n, join('<br>',
         map { '{{' . $_ . '|' . ($mod->{$_} * 100) . '%}}' } @diff));
   }
}

sub print_ranks {
   my ($F, $tag, @vals) = @_;
   my $n;
   print_line($F, $tag . ++$n, $_) foreach @vals;
}

sub print_ranks_opt {
   my ($F, $tag, @vals) = @_;
   return unless any(@vals);
   my $n;
   print_line($F, $tag . ++$n, $_ || 0) foreach @vals;
}

sub any {
   foreach my $val (@_) {
      return 1 if $val;
   }
   return;
}

my %build_map = (
   comp_milUnit_animalTrainer    => 'animal',
   comp_milUnit_barracks         => 'barracks',
   comp_milUnit_bigfootSchool    => 'bigfoot',
   comp_milUnit_frontierBarracks => 'frontier',
   comp_milUnit_laserbarracks    => 'optics facility',
   comp_milUnit_prestige         => 'prestige',
   comp_milUnit_raiderbarracks   => 'raider',
   comp_milUnit_silverWolves     => 'mercenary vault',
   comp_milUnit_vehiclefactory   => 'vehicle',
);

sub unit_cost {
   my ($F, $unit) = @_;
   my $build = $unit->build_cost();
   my $heal = $unit->heal_cost();
   return unless $build || $heal;
   print $F "==Cost==\n";

   if ($build) {
      print $F "{{BuildCost\n";
      if (my $build = $unit->building()) {
         print_line($F, 'building', $build_map{$build} || $build);
      }
      print_line($F, $_, $build->{$_}) foreach BN->sort_amount(keys %$build);
      print $F "}}\n";
   }

   if ($heal) {
      print $F "{{HealCost\n";
      print_line($F, 'building', $unit->heal_building());
      print_line($F, $_, $heal->{$_}) foreach BN->sort_amount(keys %$heal);
      print $F "}}\n";
   }

   print $F "\n";
}

sub print_line {
   my ($F, $tag, $val) = @_;
   return 0 unless defined $val;
   printf $F "| %-14s = %s\n", $tag, $val;
   return 1;
}

sub enemy_profile {
   my ($F, $units, $affil) = @_;
   my $unit = $units->[0];
   my (@notes, @tags);
   print $F "{{UnitInfobox\n";
   profile_line($F, 'image', BN::Out->icon($unit->icon()));
   profile_line($F, 'name', $unit->name());
   if (my $short = $unit->shortname()) {
      profile_line($F, 'shortname', $short) unless $short eq $unit->name();
   }
   profile_line($F, 'ut', $unit->type());
   profile_line($F, 'affiliation', $affil);
   profile_line($F, 'immunities', $unit->immunities());
   profile_line($F, 'blocking', $unit->blocking());

   my $has_armor;
   foreach my $u (@$units) {
      my ($rank) = $u->ranks();
      if ($rank->armor()) {
         $has_armor = 1;
         damage_mods($F, 'armor', $rank->armor_mods());
         if (my $type = $rank->armor_type()) {
            push @notes, 'No armor while stunned' if $type eq 'active';
         }
         last;
      }
   }

   my $has_dodge;
   foreach my $u (@$units) {
      my ($rank) = $u->ranks();
      if ($rank->dodge()) {
         $has_dodge = 1;
         last;
      }
   }

   if (my ($rank) = $unit->ranks()) {
      damage_mods($F, 'base', $rank->damage_mods());
   }

   foreach my $i (0 .. $#$units) {
      $unit = $units->[$i];
      my $n = ($i % 3) + 1;
      if ($n == 1) {
         $n = '' if $i == $#$units;
         if ($i) {
            profile_line($F, 'game file name', join(', ', @tags));
            @tags = ();
            print $F "}}\n";
            print $F "{{UnitInfobox\n";
            profile_line($F, 'name', '-');
            profile_line($F, 'affiliation', $affil);
         }
      }

      profile_line($F, 'enemylevel'.$n, $unit->level());
      if (my ($rank) = $unit->ranks()) {
         profile_line($F, 'hp'.$n, BN->commify($rank->hp()));
         profile_line($F, 'armor'.$n, BN->commify($rank->armor() || 0))
            if $has_armor;
         profile_line($F, 'dodge'.$n, $rank->dodge() || 0) if $has_dodge;
         profile_line($F, 'bravery'.$n, BN->commify($rank->bravery()));
         profile_line($F, 'defense'.$n, BN->commify($rank->defense()));
         if (my $uv = $rank->uv()) {
            profile_line($F, 'uv'.$n, $uv);
            my $sp = $rank->sp_reward();
            profile_line($F, 'spreward'.$n, $sp) unless $sp == $uv*4;
            my $gold = $rank->gold_reward();
            profile_line($F, 'goldreward'.$n, $gold) unless $gold == $uv*20;
         }
      }
      push @tags, $unit->tag();
   }

   profile_line($F, 'notes', join('<br>', @notes)) if @notes;
   profile_line($F, 'game file name', join(', ', @tags));
   print $F "}}\n==Overview==\n\n"
}

sub enemy_defense {
   my ($F, $units) = @_;
   my ($aprev, $prev, $iprev, %adiff, %diff, $idiff);
   CHECK: foreach my $unit (@$units) {
      my ($rank) = $unit->ranks() or next;
      my $def = $rank->damage_mods();
      if ($prev) {
         while (my ($k,$v) = each %$def) {
            $diff{$k} = 1 unless $prev->{$k} == $v;
         }
      }
      $prev = $def;

      next unless $rank->armor();
      $def = $rank->armor_mods();
      if ($aprev) {
         while (my ($k,$v) = each %$def) {
            $adiff{$k} = 1 unless $aprev->{$k} == $v;
         }
      }
      $aprev = $def;

      my $immune = $unit->immunities() || '';
      $idiff = 1 if defined($iprev) && $iprev ne $immune;
      $iprev = $immune;
   }
   return unless %diff || %adiff || $idiff;

   print $F "==Damage mods==\n";
   print $F qq({| class="wikitable"\n|-\n);
   print $F '! Defense', map({ ' !! ' . $_->level() } @$units), "\n";

   if (%adiff) {
      print $F "|-\n! Armor\n";
      my @keys = sort keys %adiff;
      foreach my $unit (@$units) {
         my ($rank) = $unit->ranks() or next;
         if ($rank->armor()) {
            print $F '| ', format_defense($rank->armor_mods(), \@keys), "\n";
         }
         else {
            print $F "| -\n";
         }
      }
   }

   if (%diff) {
      print $F "|-\n! Base\n";
      my @keys = sort keys %diff;
      foreach my $unit (@$units) {
         my ($rank) = $unit->ranks() or next;
         print $F '| ', format_defense($rank->damage_mods(), \@keys), "\n";
      }
   }

   if ($idiff) {
      print $F "|-\n! Immunities\n";
      foreach my $unit (@$units) {
         print $F '| ', ($unit->immunities() || ''), "\n";
      }
   }

   print $F "|}\n\n";
}

sub format_defense {
   my ($mods, $keys) = @_;
   my @mods;
   foreach my $key (@$keys) {
      my $val = $mods->{$key} * 100;
      push @mods, "{{$key|$val%}}";
   }
   return join '<br>', @mods;
}

sub enemy_attacks {
   my ($F, $units, $affil) = @_;
   print $F "==Attacks==\n";
   foreach my $unit (@$units) {
      if (@$units > 1) {
         my $level = $unit->level();
         print $F "===Level $level attacks===\n";
      }
      old_attacks($F, $unit, $affil);
   }
   print $F "\n";
}

sub old_attacks {
   my ($F, $unit, $affil) = @_;
   my $power = 0;
   my $accuracy = 0;
   my $crit = 0;
   if (my ($rank) = $unit->ranks()) {
      $power = $rank->power() || 0;
      $accuracy = $rank->accuracy() || 0;
      $crit = $rank->crit() || 0;
   }
   my $id = 'id="' . ($affil || 'attack') . '"';

   print $F qq{<div class="tabber" $id>\n};
   foreach my $weap ($unit->weapons()) {
      my $name = $weap->name();
      print $F qq{<div class="tabbertab" title="$name" $id>\n};
      print $F "{{WeaponBox\n";
      print_line($F, 'game file name', $weap->tag());
      print_line($F, 'affiliation', $affil);
      print_line($F, 'ammo', $weap->ammo());
      print_line($F, 'reload', $weap->reload());
      print_line($F, 'attacks', '');
      print $F qq{<div class="tabber" $id>\n};

      my @attacks = $weap->attacks();
      foreach my $attack (@attacks) {
         $name = $attack->name();
         print $F qq{<div class="tabbertab" title="$name" $id>\n};
         print $F "{{UnitAttackBox\n";
         my $r = 1;
         print_line($F, 'affiliation', $affil);
         print_line($F, 'nocat', 'true') unless $affil;

         if (is_aoe($attack->target_area())
            || is_aoe($attack->damage_area()))
         {
            my $file = $attack->filename($unit);
            print_line($F, 'image', "[[File:$file.png]]");
         }

         print_line($F, 'weaponicon', BN::Out->icon($attack->icon(), '40px'));
         $r += print_line($F, 'offense', $attack->offense($accuracy));
         $r += print_line($F, 'damage', $attack->damage($power));
         $r += print_line($F, 'armorpiercing', $attack->armorpiercing());
         $r += print_line($F, 'crit', $attack->crit($crit));
         $r += print_line($F, 'ammoused', $attack->ammoused());
         $r += print_line($F, 'range', $attack->range());
         $r += print_line($F, 'lof', $attack->lof());
         $r += print_line($F, 'cooldown', $attack->cooldown() || undef);
         $r += print_line($F, 'globalcooldown',
            $attack->globalcooldown() || undef) if @attacks > 1;
         $r += print_line($F, 'preptime', $attack->preptime() || undef);
         $r += print_line($F, 'effects', $attack->effects());
         print_line($F, 'targets', $attack->targets());
         print_line($F, 'targetbox-rows', $r) if $r > 7;
         print_line($F, 'notes', $attack->notes());
         print_line($F, 'game file name', $attack->tag());
         print $F "}}</div>\n";
      }

      print $F "</div>\n}}</div>\n";
   }

   print $F "</div>\n{{Clear}}\n";
}

sub is_aoe {
   my ($area) = @_;
   return unless $area;
   my $squares = $area->{data} or return;
   return @$squares > 1;
}

sub guess_affil {
   my ($unit) = @_;
   my $tag = $unit->tag();
   return 'fr'     if $tag =~ /fr_/;
   return 'inf'    if $tag =~ /_zombie_/;
   return 'raider' if $tag =~ /_raider/;
   return 'rebel'  if $tag =~ /_rebel/;
   return 'sw'     if $tag =~ /sw_/;
   my $type = $unit->type() // '';
   return 'critter' if $type =~ /Critter|Spiderwasp/;
   return;
}

1 # end BN::Out::Units
