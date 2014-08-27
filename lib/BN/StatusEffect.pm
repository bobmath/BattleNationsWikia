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
      bless $eff, $class;
   }
   return $eff;
}

my %effect_icons = (
   Fire     => 'FireDOT',
   Poison   => 'PoisonDOT',
   Cold     => 'ColdEnvironment',
);

sub effect {
   my ($eff) = @_;
   my $family = $eff->{family} or return;
   my $icon = $effect_icons{$family} or return;
   my $dmg = $eff->{dot_BonusDamage} or return;
   return "{{$icon}} $dmg";
}

1 # end BN::StatusEffect
