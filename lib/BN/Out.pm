package BN::Out;
use strict;
use warnings;
use Digest::MD5 ();
use Algorithm::Diff qw( diff );
use BN;
use BN::Out::Buildings;
use BN::Out::Missions;
use BN::Out::Units;
use BN::Out::BossStrikes;
use BN::Out::Levels;
use BN::Out::Guilds;
use BN::Out::Other;

sub write {
   BN::Out::Units->write();
   BN::Out::Buildings->write();
   BN::Out::Missions->write();
   BN::Out::BossStrikes->write();
   BN::Out::Levels->write();
   BN::Out::Guilds->write();
   BN::Out::Other->write();
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
   unshift @path, 'data';
   for my $num (0 .. $#path-1) {
      my $dir = join('/', @path[0..$num]);
      mkdir $dir unless $seen_files{lc($dir)}++;
   }
   my $file = join('/', @path);
   my $num = ++$seen_files{lc($file)};
   $file .= '-' . $num if $num > 1;
   return $file;
}

sub icon {
   my ($class, $icon, @opts) = @_;
   return $icon unless defined $icon;
   $icon =~ s{^bundle://}{};
   $icon =~ s/\.png$//;
   $icon =~ s/\@2x$//;
   return '[[' . join('|', "File:\u$icon.png", @opts) . ']]';
}

my $MD5;

sub checksum {
   my ($class, $file) = @_;
   open my $F, '<', $file or die "Can't read $file: $!";
   unless ($MD5) {
      open $MD5, '>', 'data/md5.txt' or die "Can't write md5.txt: $!";
   }
   my $md5 = Digest::MD5->new();
   $md5->addfile($F);
   close $F;
   $file =~ s{^data/}{};
   print $MD5 $file, "\t", $md5->hexdigest(), "\n";
}

sub show_diffs {
   $MD5 = undef;
   open my $OLD, '<', 'old/md5.txt' or return;
   open my $NEW, '<', 'data/md5.txt' or return;
   my $diffs = diff([<$OLD>], [<$NEW>]);
   close $OLD;
   close $NEW;
   foreach my $hunk (@$diffs) {
      my %flags;
      foreach my $line (@$hunk) {
         $line->[2] =~ s/\t.*//;
         $flags{$line->[2]} |= ($line->[0] eq '-') ? 1 : 2;
      }
      foreach my $line (@$hunk) {
         if ($line->[0] eq '-') {
            $line->[0] = '!' if $flags{$line->[2]} == 3;
         }
         else {
            next if $flags{$line->[2]} == 3;
         }
         print $line->[0], $line->[2];
      }
   }
}

1 # end BN::Out;
