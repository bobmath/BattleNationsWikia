package BN::Mission;
use strict;
use warnings;

my $missions;
my $json_file = 'Missions.json';

sub all {
   my ($class) = @_;
   $missions ||= BN::File->json($json_file);
   return map { $class->get($_) } sort keys %$missions;
}

sub get {
   my ($class, $key) = @_;
   return unless $key;
   $missions ||= BN::File->json($json_file);
   my $mis = $missions->{$key} or return;
   if (ref($mis) eq 'HASH') {
      bless $mis, $class;
      $mis->{_tag} = $key;
      my $name = BN::Text->get($mis->{title}) || $key;
      $name .= ' (Hidden)' if $mis->{hideIcon} && $name !~ /hidden/i;
      $name =~ s/\x{2026}/.../g;
      $mis->{_name} = $name;
   }
   return $mis;
}

sub get_by_name {
   my ($class, $key) = @_;
   return unless defined $key;
   foreach my $mis ($class->all()) {
      return $mis if $mis->{_name} eq $key;
   }
   return;
}

BN->simple_accessor('name');
BN->simple_accessor('tag');
BN->simple_accessor('hidden', 'hideIcon');

sub page {
   my ($class, $level) = @_;
   return 'Missions' unless $level;
   my $lo = int(($level - 1) / 10) * 10 + 1;
   my $hi = $lo + 9;
   my $max = BN::Level->max();
   $hi = $max if $hi > $max && $lo < $max;
   return "Level $lo-$hi missions";
}

sub wikilink {
   my ($mis, $text) = @_;
   my $page = $mis->page($mis->level());
   $text //= $mis->{_name};
   return "[[$page#$mis->{_name}|$text]]";
}

sub level {
   my ($mis) = @_;
   return $mis->{_level} if exists $mis->{_level};
   BN::Prereqs->calc_levels();
   return $mis->{_level};
}

sub prereqs {
   my ($mis) = @_;
   my $rules = $mis->{startRules} or return;
   my @prereqs;
   foreach my $key (sort keys %$rules) {
      my $rule = $rules->{$key} or next;
      my $prereq = $rule->{prereq} or next;
      push @prereqs, $prereq;
   }
   return @prereqs;
}

BN->accessor(rewards => sub {
   my ($mis) = @_;
   return BN->format_amount(delete($mis->{rewards}), 0, ' &nbsp; ');
});

sub objectives {
   my ($mis) = @_;
   my $objectives = $mis->{objectives} or return;
   my @obj;
   foreach my $key (sort keys %$objectives) {
      my $obj = $objectives->{$key} or next;
      my $prereq = $obj->{prereq} or next;
      push @obj, $prereq;
   }
   return @obj;
}

sub unlocks_buildings {
   my ($mis) = @_;
   if (!exists $mis->{_unlocks_buildings}) {
      $_->{_unlocks_buildings} = undef foreach BN::Mission->all();
      foreach my $bld (BN::Building->all()) {
         foreach my $id ($bld->mission_reqs()) {
            my $m = BN::Mission->get($id) or next;
            push @{$m->{_unlocks_buildings}}, $bld->tag();
         }
      }
   }
   return unless $mis->{_unlocks_buildings};
   return map { BN::Building->get($_) } @{$mis->{_unlocks_buildings}};
}

sub unlocks_units {
   my ($mis) = @_;
   if (!exists $mis->{_unlocks_units}) {
      $_->{_unlocks_units} = undef foreach BN::Mission->all();
      foreach my $unit (BN::Unit->all()) {
         foreach my $id ($unit->mission_reqs()) {
            my $m = BN::Mission->get($id) or next;
            push @{$m->{_unlocks_units}}, $unit->tag();
         }
      }
   }
   return unless $mis->{_unlocks_units};
   return map { BN::Unit->get($_) } @{$mis->{_unlocks_units}};
}

sub scripts {
   my ($mis) = @_;
   my %scripts;
   $scripts{'1start'}    = get_script($mis->{startScript});
   $scripts{'2desc'}     = get_script($mis->{description});
   $scripts{'3finish'}   = get_script($mis->{finishScript});
   $scripts{'4complete'} = get_script($mis->{completeScript});
   return \%scripts;
}

my $dialogs;

sub get_script {
   my ($script) = @_;
   $script = $script->{scriptId} if ref($script);
   return $script unless $script;
   $dialogs ||= BN::File->json('Dialogs.json');
   my $data = $dialogs->{$script} or return $script;
   foreach my $lines (@$data) {
      my $text = $lines->{text} or next;
      foreach my $line (@$text) {
         $line->{_title} = BN::Text->get($line->{title}) if $line->{title};
         $line->{_body} = BN::Text->get($line->{body});
      }
   }
   return $data;
}

sub encounters {
   my ($mis) = @_;
   if (!exists $mis->{z_encounters}) {
      $mis->{z_encounters} = undef;
      if (my $objectives = $mis->{objectives}) {
         foreach my $key (sort keys %$objectives) {
            my $objective = $objectives->{$key} or next;
            my $prereq = $objective->{prereq} or next;
            my $t = $prereq->{_t} or next;
            if ($t eq 'DefeatEncounterPrereqConfig') {
               my $id = $prereq->{encounterId} or next;
               push @{$mis->{z_encounters}}, $id;
            }
            elsif ($t eq 'DefeatEncounterSetPrereqConfig') {
               my $ids = $prereq->{encounterIds} or next;
               push @{$mis->{z_encounters}}, @$ids;
            }
         }
      }
   }
   return unless $mis->{z_encounters};
   return map { BN::Encounter->get($_) } @{$mis->{z_encounters}};
}

sub completion {
   my ($mis) = @_;
   return $mis->{z_completion} ||= BN::Mission::Completion->new($mis->{_tag});
}

package BN::Mission::Completion;

sub all {
   return map { $_->completion() } BN::Mission->all();
}

sub get {
   my ($class, $key) = @_;
   my $mis = BN::Mission->get($key) or return;
   return $mis->completion();
}

sub new {
   my ($class, $id) = @_;
   return bless {
      _parent => $id,
      z_prereqs => [{ type => 'BN::Mission', ids => [$id] }],
   }, $class;
}

sub level {
   my ($self) = @_;
   return $self->{_level} if exists $self->{_level};
   BN::Prereqs->calc_levels();
   return $self->{_level};
}

sub prereqs {
   my ($self) = @_;
   my $parent = BN::Mission->get($self->{_parent}) or return;
   my $objectives = $parent->{objectives} or return;
   my @prereqs;
   foreach my $key (sort keys %$objectives) {
      my $objective = $objectives->{$key} or next;
      my $prereq = $objective->{prereq} or next;
      push @prereqs, $prereq;
   }
   return @prereqs;
}

1 # end BN::Mission::Completion
