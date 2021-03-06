package BN::Encounter;
use strict;
use warnings;

my (%encounters, %tables);
sub load {
   return if %encounters;
   foreach my $file (qw( BattleEncounters.json NavalEncounters.json
      BSEncounters.json ))
   {
      my $json = eval { BN::File->json($file) };
      warn $@ if $@;
      next unless $json;
      if (my $armies = $json->{armies}) {
         while (my ($k,$v) = each %$armies) {
            $encounters{$k} = $v;
         }
      }
      if (my $tables = $json->{tables}) {
         while (my ($k,$v) = each %$tables) {
            $tables{$k} = $v;
         }
      }
   }
   die 'No encounters found' unless %encounters;
}

sub all {
   my ($class) = @_;
   load() unless %encounters;
   return map { $class->get($_) } sort grep { !/^test/ } keys %encounters;
}

my %names = (
   rndEnc_raiders    => 'Raiders',
);

sub get {
   my ($class, $key) = @_;
   return unless $key;
   load() unless %encounters;
   my $enc = $encounters{$key} or return;
   if (ref($enc) eq 'HASH') {
      bless $enc, $class;
      $enc->{_tag} = $key;
      my $nm = $enc->{name} // '';
      $enc->{_name} = BN::Text->get($nm) || $names{$nm} || $key;
   }
   return $enc;
}

BN->simple_accessor('name');
BN->simple_accessor('tag');
BN->simple_accessor('icon', 'icon');
BN->simple_accessor('map', 'bgImage');

BN->accessor(rewards => sub {
   my ($enc) = @_;
   return BN->flatten_amount(delete $enc->{rewards});
});

BN->list_accessor(unit_ids => sub {
   my ($enc) = @_;
   return _unit_ids($enc->{units});
});

BN->list_accessor(player_unit_ids => sub {
   my ($enc) = @_;
   return _unit_ids($enc->{playerUnits});
});

sub _unit_ids {
   my ($units) = @_;
   return unless $units;
   my %units;
   foreach my $unit (@$units) {
      my $id = $unit->{unitId} or next;
      $units{$id} = 1;
   }
   return sort keys %units;
}

sub waves {
   my ($enc) = @_;
   my $units = $enc->{units} or return;
   my @waves;
   foreach my $unit (@$units) {
      my $id = $unit->{unitId} or next;
      push @{$waves[$unit->{waveNumber}||0]}, $id;
   }
   return \@waves;
}

my %enc_tables;
sub tables {
   my ($enc) = @_;
   if (!%enc_tables) {
      foreach my $key (sort keys %tables) {
         my $table = $tables{$key};
         foreach my $inf (@{$table->{encounters}}) {
            push @{$tables{$inf->{encounterId}}}, $key;
         }
      }
   }
   my $tbls = $enc_tables{$enc->tag()} or return;
   return @$tbls;
}

sub layout_width {
   my ($enc) = @_;
   return ($enc->{layoutId} || '') eq 'equal_3x3' ? 1 : 2;
}

my %grid_map = (
   '2,1'  => 1,
   '1,1'  => 2,
   '0,1'  => 3,
   '-1,1' => 4,
   '-2,1' => 5,
   '2,2'  => 6,
   '1,2'  => 7,
   '0,2'  => 8,
   '-1,2' => 9,
   '-2,2' => 10,
   '1,3'  => 11,
   '0,3'  => 12,
   '-1,3' => 13,
);
sub unit_positions {
   my ($enc, $wave) = @_;
   my $wid = $enc->layout_width();
   $wave ||= 1;
   my (@units, @rand, %taken);
   foreach my $info (@{$enc->{units}}) {
      next unless ($info->{waveNumber} || 0) + 1 == $wave;;
      my $unit = BN::Unit->get($info->{unitId}, 1) or next;
      if (defined(my $pos = $info->{gridId})) {
         my $x = 2 - ($pos % 5);
         my $y = int($pos / 5) + 1;
         $taken{$y}{$x} = 1;
         push @units, { unit=>$unit, x=>$x, y=>$y, grid=>$grid_map{"$x,$y"} };
      }
      else {
         push @rand, $unit;
      }
   }
   srand(0);
   foreach my $unit (@rand) {
      my $pref = $unit->preferred_row() || 1;
      for my $i (0 .. 2) {
         my $y = $i + $pref;
         $y -= 3 if $y > 3;
         my $row_wid = $y < 3 ? $wid : 1;
         my $max = 2*$row_wid + 1;
         my $row = $taken{$y} ||= { };
         next if keys(%$row) >= $max;
         my $x;
         do {
            $x = int(rand $max) - $row_wid;
         } while $row->{$x};
         $row->{$x} = 1;
         push @units, { unit=>$unit, x=>$x, y=>$y, grid=>$grid_map{"$x,$y"} };
         last;
      }
   }
   return @units;
}

sub level {
   my ($enc) = @_;
   # level given in the game files is unreliable
   $enc->calc_levels() unless exists $enc->{_level};
   return $enc->{_level};
}

sub calc_levels {
   my ($class) = @_;
   $_->{_level} = undef foreach $class->all();

   foreach my $table (values %tables) {
      my $levels = $table->{levels} or next;
      my $min = $levels->{min} or next;
      my $elist = $table->{encounters} or next;
      foreach my $e (@$elist) {
         my $enc = $class->get($e->{encounterId}) or next;
         $enc->{_level} = $min
            if !defined($enc->{_level}) || $min < $enc->{_level};
      }
   }

   foreach my $mis (BN::Mission->all()) {
      next if $mis->hidden();
      my $level = $mis->level() or next;
      foreach my $enc ($mis->encounters()) {
         $enc->{_level} = $level
            if !defined($enc->{_level}) || $level < $enc->{_level};
      }
   }
}

sub environment {
   my ($enc) = @_;
   return BN::StatusEffect->get($enc->{envStatEff});
}

1 # end BN::Encounter
