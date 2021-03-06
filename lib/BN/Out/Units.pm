package BN::Out::Units;
use strict;
use warnings;
use Data::Dump qw( dump );

sub write {
   my %enemies;
   foreach my $unit (BN::Unit->all()) {
      if ($unit->side() ne 'Player') {
         my $name = $unit->wiki_page();
         push @{$enemies{$name}}, $unit;
         next;
      }
      my $file = BN::Out->filename('units', $unit->wiki_page());
      open my $F, '>', $file or die "Can't write $file: $!";;

      unit_profile($F, $unit);
      unit_weapons($F, $unit);
      unit_ranks($F, $unit);
      unit_cost($F, $unit);
      print $F "__DUMP__\n", dump($unit), "\n";
      close $F;
      BN::Out->compare($file);
   }

   foreach my $name (sort keys %enemies) {
      my $units = $enemies{$name} or die;
      @$units = sort {($a->level()||0) <=> ($b->level()||0)} @$units or next;
      my $dir = $units->[0]->side() eq 'Hostile' ? 'enemies' : 'other';
      my $file = BN::Out->filename($dir, $name);
      open my $F, '>', $file or die "Can't write $file: $!";
      print $F $name, "\n";

      my $affil = guess_affil($units);
      enemy_profile($F, $units, $affil);
      enemy_defense($F, $units);
      enemy_attacks($F, $units, $affil);

      print $F "\n__DUMP__\n", dump($units), "\n";
      close $F;
      BN::Out->compare($file);
   }
}

sub unit_profile {
   my ($F, $unit) = @_;
   my @notes;
   print $F $unit->wiki_page(), "\n";
   print $F "{{UnitProfile\n";
   profile_line($F, 'image', BN::Out->icon($unit->icon()));
   profile_line($F, 'name', $unit->name())
      unless $unit->name() eq $unit->wiki_page();
   if (my $short = $unit->shortname()) {
      profile_line($F, 'shortname', $short) unless $short eq $unit->name();
   }
   profile_line($F, 'unit type', $unit->type());
   profile_line($F, 'unit level', $unit->level());
   profile_line($F, 'building required', $unit->building_req());
   profile_line($F, 'other requirements', $unit->other_reqs());
   profile_line($F, 'immunities', $unit->immunities());
   profile_line($F, 'blocking', $unit->blocking());
   unit_defense($F, $unit, \@notes);
   profile_line($F, 'limit', $unit->deploy_limit());
   spawned_unit($F, $unit);
   profile_line($F, 'notes', join('<br>', @notes)) if @notes;
   profile_line($F, 'game file name', $unit->tag());
   print $F "}}\n";
   if (my $desc = $unit->description()) {
      print $F "{{IGD|$desc}}\n";
   }
   print $F "==Overview==\n{{Clear}}\n\n";
}

sub spawned_unit {
   my ($F, $unit) = @_;
   my $spawn = $unit->spawned_unit() or return;
   my $name = BN::Out->icon($spawn->icon(), '30px', 'link=');
   $name .= ' ' if defined $name;
   $name .= $spawn->shortlink();
   profile_line($F, 'spawn', $name);
}

sub unit_defense {
   my ($F, $unit, $notes) = @_;
   my ($hp, $hp_mods, $armor, $armor_mods, %show);
   my $rank = ($unit->ranks())[-1];
   $hp = $rank->hp();
   flag_defense($hp_mods = $rank->damage_mods(), \%show);
   if ($armor = $rank->armor()) {
      flag_defense($armor_mods = $rank->armor_mods(), \%show);
      if (my $type = $rank->armor_type()) {
         push @$notes, 'No armor while stunned' if $type eq 'active';
      }
   }
   my @show = sort keys %show;
   profile_line($F, 'hp defense',
      show_defense("{{HP|$hp}}", $hp_mods, @show));
   profile_line($F, 'armor defense',
      show_defense("{{Armor|$armor}}", $armor_mods, @show)) if $armor;
}

sub flag_defense {
   my ($def, $show) = @_;
   while (my ($k, $v) = each %$def) {
      $show->{$k} = 1 unless $v == 1;
   }
}

sub show_defense {
   my ($hp, $def, @show) = @_;
   my @def = ($hp);;
   foreach my $key (@show) {
      my $val = int(($def->{$key} // 1) * 100 + 0.5);
      if ($val > 100) {
         $key .= 'Vuln';
      }
      elsif ($key eq 'Cold') {
         $key .= 'Damage';
      }
      push @def, "{{$key|$val%}}";
   }
   return join '<br>', @def;
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
   printf $F "| %-18s = %s\n", $tag, $val if defined $val;
}

sub unit_weapons {
   my ($F, $unit) = @_;
   my $first = 1;
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
         print_line($F, 'attack' . ++$n, '');
         print $F "{{AttackBox\n";
         print_line($F, 'name', $attack->name());
         print_line($F, 'image',
            '[[File:' . $attack->filename($unit) . '_Damage.gif]]');
         print_line($F, 'weaponicon', BN::Out->icon($attack->icon(), '40px'));
         print_line($F, 'rank', $rank);
         print_line($F, 'damagetype', $attack->dmgtype());
         print_line($F, 'mindmg', $attack->mindmg());
         print_line($F, 'maxdmg', $attack->maxdmg());
         rank_mods($F, 'power', 5, $attack->unit_damage_mult(),
            map { $_->power() } $unit->ranks());
         print_line($F, 'numattacks', $attack->numattacks());
         print_line($F, 'baseoffense', $attack->offense());
         rank_mods($F, 'accuracy', 5, $attack->unit_offense_mult(),
            map { $_->accuracy() } $unit->ranks());
         print_line($F, 'basecrit', $attack->base_crit());
         rank_mods($F, 'critmod', 0, $attack->unit_crit_mult(),
            map { $_->crit() } $unit->ranks());
         print_line($F, 'critbonus', $attack->crit_bonuses());
         print_line($F, 'dottype', $attack->dottype());
         print_line($F, 'dotduration', $attack->dotduration());
         print_line($F, 'cost', BN->format_amount($attack->cost(), 0, ', '));
         attack_details($F, $attack, $nattacks);
         print $F "}}\n";
      }
      print $F "}}\n";
   }
   print $F "</tabber>\n{{Clear}}\n\n" unless $first;
}

sub rank_mods {
   my ($F, $tag, $step, $mult, @vals) = @_;
   $mult //= 1;
   $_ = ($_ || 0) * $mult foreach @vals;
   my $same = 1;
   for my $i (0 .. $#vals) {
      if ($vals[$i] != $i * $step) {
         $same = 0;
         last;
      }
   }
   # kludge - attackbox uses power to determine number of ranks
   return if $same && ($tag ne 'power' || @vals == 6);
   print_line($F, $tag, join('; ', @vals));
}

sub attack_details {
   my ($F, $attack, $nattacks) = @_;
   my $r = 0;
   $r += print_line($F, 'ammoused', $attack->ammoused());
   $r += print_line($F, 'range', $attack->range());
   $r += print_line($F, 'lof', $attack->lof());
   $r += print_line($F, 'armorpiercing', $attack->armorpiercing());
   $r += print_line($F, 'effects', $attack->effects());
   $r += print_line($F, 'suppression', $attack->suppression());
   $r += print_line($F, 'preptime', $attack->preptime() || undef);

   my $gcd = $nattacks > 1 && $attack->globalcooldown();
   if (my $cd = $attack->cooldown()) {
      $r += print_line($F, 'cooldown', $cd) unless $gcd && $gcd >= $cd;
   }
   $r += print_line($F, 'globalcooldown', $gcd) if $gcd;

   print_line($F, 'targets', $attack->targets());
   print_line($F, 'notes', $attack->notes());
   print_line($F, 'game file name', $attack->tag());
   return $r;
}

sub unit_ranks {
   my ($F, $unit) = @_;
   my @ranks = $unit->ranks() or return;
   my @ranks1 = @ranks[0 .. $#ranks-1];
   print $F "==Statistics==\n{{UnitRanksBox\n";
   print_ranks($F, 'sp', undef, map { BN->commify($_->sp()) } @ranks1);
   short_ranks($F, 'hp', map { $_->hp() } @ranks);
   short_ranks($F, 'armor', map { $_->armor() } @ranks) if $unit->max_armor();
   short_ranks($F, 'bravery', map { $_->bravery() } @ranks);
   short_ranks($F, 'defense', map { $_->defense() } @ranks);
   short_ranks($F, 'dodge', map { $_->dodge() } @ranks);

   if ((my $max = $unit->total_attacks()) > 1) {
      short_ranks($F, 'ability', map {
         my $slots = $_->ability_slots();
         $slots <= $max ? $slots : $max;
      } @ranks);
   }

   damage_mod_ranks($F, 'armormod',
      map { $_->armor() && $_->armor_mods() } @ranks);
   damage_mod_ranks($F, 'damagemod', map { $_->damage_mods() } @ranks);

   print_ranks($F, 'pc', undef, map { $_->cost() } @ranks1);
   print_ranks($F, 'reward', undef,
      map { BN->format_amount($_->level_up_rewards()) } @ranks1);
   short_ranks($F, 'uv', map { $_->uv() } @ranks);

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
      pop @reqs until $reqs[-1];
      $reqs[0] ||= $unit->level() || 1;
      $reqs[$_] ||= $reqs[$_-1] foreach 1 .. $#reqs;
      print_line($F, 'levelreq', join('; ', @reqs));
   }

   @reqs = map { $_->prerank_req() } @ranks;
   if (any(@reqs)) {
      my $prev = BN::Level->max();
      pop @reqs until $reqs[-1];
      for my $i (reverse 1 .. $#reqs) {
         my $req = $reqs[$i] // $prev;
         $reqs[$i] = "$req-$prev" if $req < $prev;
         $prev = $req - 1;
      }
      $reqs[0] = ($unit->level() || 1) . '-' . $prev;
      print_line($F, 'prerankreq', join('; ', @reqs));
   }

   print $F "}}\n\n";
}

my %damage_mod_templ = (
   Cold => 'ColdDamage',
);

sub damage_mod_ranks {
   my ($F, $tag, @mods) = @_;
   my ($first, %diff);
   foreach my $mod (@mods) {
      next unless $mod;
      if ($first) {
         while (my ($key,$val) = each %$mod) {
            $diff{$key} = 1 if $first->{$key} != $val;
         }
      }
      else {
         $first = $mod;
      }
   }
   my @diff = sort keys %diff or return;
   my $n;
   foreach my $mod (@mods) {
      ++$n;
      next unless $mod;
      my @out;
      foreach my $diff (@diff) {
         my $dmg = $mod->{$diff} * 100;
         my $templ = $damage_mod_templ{$diff} || $diff;
         push @out, @diff == 1 ? "{{$templ}} $dmg%" : "{{$templ|$dmg%}}";
      }
      print_line($F, $tag . $n, join('<br>', @out));
   }
}

sub print_ranks {
   my ($F, $tag, @vals) = @_;
   my $n;
   print_line($F, $tag . ++$n, $_) foreach @vals;
}

sub short_ranks {
   my ($F, $tag, @vals) = @_;
   $_ ||= 0 foreach @vals;
   print_line($F, $tag, join('; ', @vals));
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
   comp_milUnit_drydock          => 'dry dock',
   comp_milUnit_fishhatchery     => 'fish',
   comp_milUnit_frontierBarracks => 'frontier',
   comp_milUnit_laserbarracks    => 'optics facility',
   comp_milUnit_plasmafactory    => 'plasma',
   comp_milUnit_prestige         => 'prestige',
   comp_milUnit_raiderbarracks   => 'raider',
   comp_milUnit_silverWolves     => 'mercenary vault',
   comp_milUnit_vehiclefactory   => 'vehicle',
);

sub unit_cost {
   my ($F, $unit) = @_;
   my $build = $unit->building() && $unit->build_cost();
   my $heal = $unit->heal_cost();
   return unless $build || $heal;
   print $F "==Cost==\n";

   if ($build) {
      print $F "{{BuildCost\n";
      if (my $build = $unit->building()) {
         print_line($F, 'building', $build_map{$build} || $build);
      }
      print_line($F, 'min', $unit->building_level());
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

   spawned_unit($F, $unit);
   profile_line($F, 'notes', join('<br>', @notes)) if @notes;
   profile_line($F, 'game file name', join(', ', @tags));
   print $F "}}\n";
   if (my $desc = $unit->description()) {
      print $F "{{IGD|$desc}}\n";
   }
   print $F "==Overview==\n{{Clear}}\n\n"
}

sub enemy_defense {
   my ($F, $units) = @_;
   my ($aprev, $prev, $iprev, %adiff, %diff, $idiff);
   CHECK: foreach my $unit (@$units) {
      my $immune = $unit->immunities() || '';
      $idiff = 1 if defined($iprev) && $iprev ne $immune;
      $iprev = $immune;

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
   }
   return unless %diff || %adiff || $idiff;

   print $F "==Damage mods==\n";
   print $F qq({| class="wikitable"\n|-\n);
   print $F '! Defense', map({ ' !! ' . ($_->level()||0) } @$units), "\n";

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
      my $lbl = $key eq 'Cold' ? 'ColdDamage' : $key;
      push @mods, "{{$lbl|$val%}}";
   }
   return join '<br>', @mods;
}

sub enemy_attacks {
   my ($F, $units, $affil) = @_;
   print $F "==Attacks==\n";
   if (@$units == 1) {
      old_attacks($F, $units->[0], $affil);
   }
   else {
      print $F qq{<div class="tabber" id="$affil">\n};
      foreach my $unit (@$units) {
         my $level = $unit->level() || 0;
         print $F qq{<div class="tabbertab" title="Level $level" },
            qq{id="$affil">\n};
         old_attacks($F, $unit, $affil);
         print $F qq{</div>\n};
      }
      print $F qq{</div>\n};
   }
   print $F "{{Clear}}\n";
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
   my $nocat = $affil ? undef : 'true';
   $affil ||= 'neutral';

   print $F qq{<div class="tabber" id="$affil">\n};
   foreach my $weap ($unit->weapons()) {
      my $name = $weap->name();
      print $F qq{<div class="tabbertab" title="$name" id="$affil">\n};
      print $F "{{WeaponBox\n";
      print_line($F, 'game file name', $weap->tag());
      print_line($F, 'affiliation', $affil);
      print_line($F, 'ammo', $weap->ammo());
      print_line($F, 'reload', $weap->reload());
      print_line($F, 'attacks', '');
      print $F qq{<div class="tabber" id="$affil">\n};

      my @attacks = $weap->attacks();
      foreach my $attack (@attacks) {
         $name = $attack->name();
         print $F qq{<div class="tabbertab" title="$name" id="$affil">\n};
         print $F "{{UnitAttackBox\n";
         my $r = 1;
         print_line($F, 'affiliation', $affil);
         print_line($F, 'nocat', $nocat);
         print_line($F, 'image',
            '[[File:' . $attack->filename($unit) . '_Damage.gif]]');
         print_line($F, 'weaponicon', BN::Out->icon($attack->icon(), '40px'));
         $r += print_line($F, 'offense', $attack->offense($accuracy));
         $r += print_line($F, 'damage', $attack->damage($power));
         $r += print_line($F, 'crit', $attack->crit($crit));
         $r += attack_details($F, $attack, scalar(@attacks));
         print_line($F, 'targetbox-rows', $r) if $attack->targets() && $r > 7;
         print $F "}}</div>\n";
      }

      print $F "</div>}}</div>\n";
   }

   print $F "</div>\n";
}

sub is_aoe {
   my ($area) = @_;
   return unless $area;
   my $squares = $area->{data} or return;
   return @$squares > 1;
}

sub guess_affil {
   my ($units) = @_;
   foreach my $unit (@$units) {
      return $unit->{_affiliation} if $unit->{_affiliation};
      my $tag = $unit->tag();
      return 'fr'     if $tag =~ /^fr_/;
      return 'inf'    if $tag =~ /_zombie_/;
      return 'raider' if $tag =~ /_raider/;
      return 'rb'     if $tag =~ /^rb_/;
      return 'rebel'  if $tag =~ /_rebel/;
      return 'sn'     if $tag =~ /^ship_/;
      return 'sw'     if $tag =~ /sw_/;
      my $type = $unit->type() // '';
      return 'critter' if $type =~ /Critter|Spiderwasp/;
      return 'player' if $unit->side() eq 'Hero';
   }
   return 'neutral';
}

1 # end BN::Out::Units
