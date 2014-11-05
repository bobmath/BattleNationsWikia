package BN::Out;
use strict;
use warnings;
use BN;
use BN::Out::BossStrikes;
use BN::Out::Buildings;
use BN::Out::Guilds;
use BN::Out::Levels;
use BN::Out::Missions;
use BN::Out::Other;
use BN::Out::Transformations;
use BN::Out::Units;

sub write {
   print "Writing wikitext\n";
   BN::Out::BossStrikes->write();
   BN::Out::Buildings->write();
   BN::Out::Guilds->write();
   BN::Out::Levels->write();
   BN::Out::Missions->write();
   BN::Out::Other->write();
   BN::Out::Transformations->write();
   BN::Out::Units->write();
}

my (%seen_files, $LIST);

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
   open $LIST, '>', 'data/list.txt' unless $LIST;
   print $LIST $file, "\n";
   my $old = $file . '.old';
   rename $file, $old unless -f $old;
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

sub compare {
   my ($class, $file) = @_;
   open my $NEW, '<', $file or return;
   my $equal;
   if (open my $OLD, '<', "$file.old") {
      $equal = equal_files($OLD, $NEW);
      close $OLD;
   }
   close $NEW;
   if ($equal) {
      unlink "$file.old";
   }
   else {
      print $file, "\n";
   }
}

sub equal_files {
   my ($F, $G) = @_;
   while (defined(my $line1 = <$F>)) {
      my $line2 = <$G>;
      return unless defined($line2) && $line1 eq $line2;
      return 1 if $line1 eq "__DUMP__\n";
   }
   my $line2 = <$G>;
   return if defined($line2);
   return 1;
}

1 # end BN::Out;
