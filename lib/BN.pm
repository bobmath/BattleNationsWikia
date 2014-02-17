package BN;
use strict;
use warnings;

sub simple_accessor {
   my ($class, $name, $key) = @_;
   $key ||= '_' . $name;
   my $sym = caller() . '::' . $name;
   no strict 'refs';
   die "$sym already defined" if exists &$sym;
   *$sym = sub { $_[0]{$key} };
}

sub accessor {
   my ($class, $name, $sub) = @_;
   my $uname = '_' . $name;
   my $sym = caller() . '::' . $name;
   no strict 'refs';
   die "$sym already defined" if exists &$sym;
   *$sym = sub {
      my ($obj) = @_;
      return $obj->{$uname} if exists $obj->{$uname};
      return $obj->{$uname} = $sub->($obj);
   };
}

sub multi_accessor {
   my ($class, @args) = @_;
   my $sub = pop @args;
   my @unames = map { '_' . $_ } @args;
   foreach my $name (@args) {
      my $uname = '_' . $name;
      my $sym = caller() . '::' . $name;
      no strict 'refs';
      die "$sym already defined" if exists &$sym;
      *$sym = sub {
         my ($obj) = @_;
         return $obj->{$uname} if exists $obj->{$uname};
         @{$obj}{@unames} = $sub->($obj);
         return $obj->{$uname};
      };
   }
}

sub list_accessor {
   my ($class, $name, $sub) = @_;
   my $uname = 'z_' . $name;
   my $sym = caller() . '::' . $name;
   no strict 'refs';
   die "$sym already defined" if exists &$sym;
   *$sym = sub {
      my ($obj) = @_;
      return @{$obj->{$uname}} if $obj->{$uname};
      return @{$obj->{$uname}} = $sub->($obj);
   };
}

use BN::JSON;
use BN::Text;
use BN::Unit;
use BN::Weapon;
use BN::Attack;
use BN::Rank;
use BN::Building;
use BN::BLevel;
use BN::Job;
use BN::Mission;
use BN::Prereqs;

my %resource_map = (
   currency => 'nanopods',
   gear     => 'gears',
   heart    => 'merits',
   money    => 'gold',
   sbars    => 'laurels',
   sgear    => 'widgets',
   skull    => 'skulls',
   sskull   => 'powder',
   star     => 'stars',
   stooth   => 'necklaces',
   tooth    => 'teeth',
   xp       => 'XP',
);

sub flatten_amount {
   my ($class, $cost, $time) = @_;
   my %flat;
   my @src = ($cost);
   while (@src) {
      my $src = shift @src or next;
      while (my ($k,$v) = each %$src) {
         if (ref $v) { push @src, $v }
         elsif ($v) { $flat{$resource_map{$k} || $k} = $v }
      }
   }
   $flat{time} = $time if $time;
   return unless %flat;
   return \%flat;
}

my %resource_order = (
   XP        => 1,
   SP        => 2,
   time      => 3,
   nanopods  => 4,
   z2points  => 5,
   gold      => 6,
   stone     => 7,
   wood      => 8,
   iron      => 9,
   oil       => 10,
   concrete  => 11,
   lumber    => 12,
   steel     => 13,
   coal      => 14,
   bars      => 15,
   gears     => 16,
   skulls    => 17,
   teeth     => 18,
   merits    => 19,
   chem      => 20,
   stars     => 21,
   laurels   => 22,
   widgets   => 23,
   powder    => 24,
   necklaces => 25,
);

sub sort_amount {
   my ($class, @keys) = @_;
   return sort { ($resource_order{$a}||0) <=> ($resource_order{$b}||0)
      || $a cmp $b } @keys;
}

my %resource_templ = (
   chem     => 'Vials',
   z2points => 'Z2Points',
);

sub resource_template {
   my ($class, $resource, $val) = @_;
   return unless $resource;
   my $name = $resource_templ{$resource} || ucfirst($resource);
   return "{{$name}}" unless $val;
   $val = $class->commify($val) unless $resource eq 'time';
   return "{{$name|$val}}";
}

sub format_amount {
   my ($class, $cost, $time, $join) = @_;
   my $flat = $class->flatten_amount($cost, $time) or return;
   return join $join || ' ',
      map { $class->resource_template($_, $flat->{$_}) }
      $class->sort_amount(keys %$flat);
}

sub commify {
   my ($class, $val) = @_;
   if (defined $val) {
      1 while $val =~ s/(\d)(\d\d\d)\b/$1,$2/;
   }
   return $val;
}

sub format_time {
   my ($class, $time) = @_;
   return undef unless $time;
   my @fmt;
   if (my $sec = $time % 60) { unshift @fmt, $sec . 's' }
   $time = int($time/60);
   if (my $min = $time % 60) { unshift @fmt, $min . 'm' }
   $time = int($time/60);
   if (my $hr = $time % 24) { unshift @fmt, $hr . 'h' }
   $time = int($time/24);
   unshift @fmt, $time . 'd' if $time;
   return join ' ', @fmt;
}

1 # end BN
