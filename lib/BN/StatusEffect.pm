package BN::StatusEffect;
use strict;
use warnings;

my $effects;

sub get {
   my ($class, $tag) = @_;
   return unless $tag;
   $effects ||= BN::File->json('StatusEffectsConfig.json');
   my $eff = $effects->{$tag} or return;
   if (ref($eff) eq 'HASH') {
      $eff->{_tag} = $tag;
      bless $eff, $class;
   }
   return $eff;
}

BN->simple_accessor('family', 'family');
BN->simple_accessor('diminish', 'dot_Diminishing');
BN->simple_accessor('duration', 'duration');

my %effect_icons = (
   Cold              => 'ColdEnvironment',
   Fire              => 'FireDOT',
   Firemod           => 'Firemod',
   Flammable         => 'ExplosiveAmp',
   Frozen            => 'Freeze',
   Plague            => 'Plague',
   Poison            => 'PoisonDOT',
   shell_explosive   => 'Shell|type=Explosive',
   shell_piercing    => 'Shell|type=Piercing',
   shell_unstable    => 'Shell|type=Unstable',
);

sub icon {
   my ($eff) = @_;
   my $fam = $eff->{family};
   return $effect_icons{$eff->{_tag}} || $effect_icons{$fam} || $fam;
}

sub effect {
   my ($eff) = @_;
   my $family = $eff->{family} or return;
   my $icon = $effect_icons{$family} or return;
   my $type = $eff->{type} or return;
   if ($type eq 'dot') {
      my $dmg = $eff->{dot_BonusDamage} or return;
      return "{{$icon}} $dmg";
   }
   elsif ($type eq 'stun') {
      my $mod = $eff->{stun_DamageMods} or return;
      return if keys(%$mod) > 1;
      my ($val) = values %$mod;
      $val *= 100;
      return "{{$icon}} $val%";
   }
   return;
}

1 # end BN::StatusEffect
