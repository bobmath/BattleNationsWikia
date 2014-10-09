package BN::Out::Transformations;
use strict;
use warnings;

sub write {
   my $file = BN::Out->filename('info', 'Transformation');
   open my $F, '>', $file or die "Can't write $file: $!";

   my (%full, %short);
   foreach my $unit (BN::Unit->all()) {
      my $to = $unit->trans_to() or next;
      my %links;
      my $proto = 0;
      my $normal = 0;
      my $advanced = 0;
      my $archetype = 0;
      foreach my $id (keys %$to) {
         my $u = BN::Unit->get($id) or next;
         my $prob = $to->{$id} * 100;
         $links{$u->shortlink()} = sprintf('%.0f', $prob);

         my $name = $u->name() or next;
         if    ($name =~ /Proto/)     { $proto += $prob }
         elsif ($name =~ /Advanced/)  { $advanced += $prob }
         elsif ($name =~ /Archetype/) { $archetype += $prob }
         elsif ($name =~ /Colossus/)  { $archetype += $prob }
         else                         { $normal += $prob }
      }
      $short{$unit->wikilink()} = sprintf
         '%.0f%% || %.0f%% || %.0f%% || %.0f%%',
         $proto, $normal, $advanced, $archetype;

      my $out = join('<br>', map { "$_ $links{$_}%" }
         sort { $links{$b} <=> $links{$a} || $a cmp $b } keys %links);
      my $icon = BN::Out->icon($unit->icon(), 'x50px') // '';
      $icon .= ' ' if length $icon;
      $full{$unit->wikilink()} = $icon . $unit->wikilink() . ' || ' . $out;
   }

   print $F qq({| class="wikitable sortable"\n);
   print $F "! Unit !! Proto !! Normal !! Advanced !! Archetype\n";
   foreach my $name (sort keys %short) {
      print $F "|-\n| $name || $short{$name}\n";
   }
   print $F "|}\n\n";

   print $F qq({| class="wikitable"\n);
   print $F "! Unit !! Results\n";
   foreach my $name (sort keys %full) {
      print $F "|-\n| $full{$name}\n";
   }
   print $F "|}\n";

   close $F;
   BN::Out->checksum($file);
}

1 # end BN::Out::Transformations
