package BN::Out;
use strict;
use warnings;
use Digest::MD5 ();
use Algorithm::Diff qw( diff );
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
   my ($class, @path) = @_;
   foreach my $file (@path) {
      $file //= '_';
      $file =~ s/[^\w\s\-.]//g;
      $file =~ s/\s+/_/g;
      $file =~ s/^[-.]/_/;
      $file = '_' if $file eq '';
   }
   my $file = join('/', @path);
   my $num = ++$seen_files{$file};
   $file .= '-' . $num if $num > 1;
   return $file;
}

my $MD5;

sub checksum {
   my ($class, $file) = @_;
   open my $F, '<', $file or die "Can't read $file: $!";
   unless ($MD5) {
      open $MD5, '>', 'new.md5' or die "Can't write new.md5: $!";
   }
   my $md5 = Digest::MD5->new();
   $md5->addfile($F);
   close $F;
   print $MD5 $file, "\t", $md5->hexdigest(), "\n";
}

sub show_diffs {
   $MD5 = undef;
   open my $OLD, '<', 'old.md5' or return;
   open my $NEW, '<', 'new.md5' or return;
   my $diffs = diff([<$OLD>], [<$NEW>]);
   close $OLD;
   close $NEW;
   foreach my $hunk (@$diffs) {
      foreach my $line (@$hunk) {
         print $line->[0], $line->[2];
      }
   }
}

1 # end BN::Out;
