package BN::Out::Transformations;
use strict;
use warnings;

sub write {
   my $json = BN::File->json('TransformationTables.json');

   my (%table_units, %table_probs, %infected_probs);
   foreach my $unit (BN::Unit->all()) {
      my $transform = $unit->{transformationTable} or next;
      my $zomb = $transform->{ZombieCandidate} or next;
      push @{$table_units{$zomb}}, $unit;
   }
   foreach my $units (values %table_units) {
      @$units = sort { $a->name() cmp $b->name() } @$units;
   }
   foreach my $table_id (keys %table_units) {
      my $table = $json->{$table_id} or next;
      my @unit_ids = map { $_->tag() } @{$table_units{$table_id}};
      my $weight = 0;
      foreach my $row (@$table) {
         $weight += $row->{weight};
      }
      my %probs;
      foreach my $row (@$table) {
         my $unit_id = $row->{unitType} or next;
         my $prob = $row->{weight} / $weight;
         $probs{$unit_id} += $prob;
         $infected_probs{$unit_id}{$_} += $prob foreach @unit_ids;
      }
      $_ = sprintf('%.0f', $_*100) || 1 foreach values %probs;
      $table_probs{$table_id} = \%probs if %probs;
   }
   foreach my $probs (values %infected_probs) {
      $_ = sprintf('%.0f', $_*100) || 1 foreach values %$probs;
   }

   my $file = BN::Out->filename('info', 'Transformation');
   open my $F, '>', $file or die "Can't write $file: $!";

   print $F qq[{| class="wikitable mw-collapsible mw-collapsed"\n],
      "|-\n! Unit !! Result !! Chance\n";
   foreach my $table_id (
      sort { $table_units{$a}[0]->name() cmp $table_units{$b}[0]->name() }
      keys %table_units)
   {
      my $units = $table_units{$table_id} or next;
      my $probs = $table_probs{$table_id} or next;
      my @infected = sort { $probs->{$b->tag()} <=> $probs->{$a->tag()}
            || $a->name() cmp $b->name() }
         map { BN::Unit->get($_) } keys %$probs;
      my $rows = @infected or next;
      print $F qq[|-\n| rowspan="$rows" | ],
         join('<br>', map { show_unit($_) } @$units), "\n";
      my $first = 1;
      foreach my $unit (@infected) {
         my $prob = $probs->{$unit->tag()} || 0;
         print $F "|-\n" unless $first;
         $first = 0;
         print $F "| ", show_unit($unit), " || $prob%\n";
      }
   }
   print $F "|}\n\n";

   print $F qq[{| class="wikitable mw-collapsible mw-collapsed"\n],
      "|-\n! Result !! Unit !! Chance\n";
   my @infected = map { BN::Unit->get($_) } keys %infected_probs;
   foreach my $infected (sort { $a->name() cmp $b->name() } @infected) {
      my $probs = $infected_probs{$infected->tag()} or next;
      my @units = sort { $probs->{$b->tag()} <=> $probs->{$a->tag()}
            || $a->name() cmp $b->name() }
         map { BN::Unit->get($_) } keys %$probs;
      my $rows = @units or next;
      print $F qq[|-\n| rowspan="$rows" | ], show_unit($infected), "\n";
      my $first = 1;
      foreach my $unit (@units) {
         my $prob = $probs->{$unit->tag()} || 0;
         print $F "|-\n" unless $first;
         $first = 0;
         print $F "| ", show_unit($unit), " || $prob%\n";
      }
   }
   print $F "|}\n";

   close $F;
   BN::Out->checksum($file);
}

sub show_unit {
   my ($unit) = @_;
   my $icon = BN::Out->icon($unit->icon(), '40x40px') // '';
   $icon .= ' ' if length($icon);
   return $icon . $unit->wikilink();
}

1 # end BN::Out::Transformations
