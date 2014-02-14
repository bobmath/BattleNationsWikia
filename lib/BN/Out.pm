package BN::Out;
use strict;
use warnings;
use BN;
use BN::Out::Buildings;
use BN::Out::Missions;
use BN::Out::Units;

sub write {
   BN::Out::Units->write();
   BN::Out::Buildings->write();
   BN::Out::Missions->write();
}

my %seen_files;

sub filename {
   my ($class, $file, $dir) = @_;
   $file =~ s/[^\w\s\-.]//g;
   $file =~ s/\s+/_/g;
   $file =~ s/^[-.]/_/;
   $file = '_' if $file eq '';
   $file = "$dir/$file" if $dir;
   my $num = ++$seen_files{$file};
   $file .= '-' . $num if $num > 1;
   return $file;
}

1 # end BN::Out;
