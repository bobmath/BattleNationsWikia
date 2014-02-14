package BN::Weapon;
use strict;
use warnings;

sub new {
   my ($class, $weap, $key, $unit_tag) = @_;
   die unless ref($weap) eq 'HASH';
   bless $weap, $class;
   $weap->{_tag} = $key or die;
   $weap->{_unit_tag} = $unit_tag;
   $weap->{_name} = BN::Text->get($weap->{name});
   return $weap;
}

BN->simple_accessor('tag');
BN->simple_accessor('name');

BN->multi_accessor('ammo', 'reload', sub {
   my ($weap) = @_;
   my $ammo = $weap->{stats}{ammo} or return;
   return '{{Infinite}}' if $ammo < 0;
   return ($ammo, $weap->{stats}{reloadTime});
});

BN->list_accessor('attacks', sub {
   my ($weap) = @_;
   my $abilities = $weap->{abilities} or return;
   return map { BN::Attack->get($_, $weap) } @$abilities;
});

1 # end BN::Weapon
