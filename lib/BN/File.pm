package BN::File;
use strict;
use warnings;
use Digest::SHA1 ();
use File::Copy qw( copy );
use File::Glob qw( bsd_glob GLOB_NOCASE );
use File::HomeDir ();
use JSON::XS qw( decode_json );
use POSIX qw( strftime );

my ($app_dir, $new_dir);
if ($^O eq 'darwin') {
   $app_dir = '/Applications/BattleNations.app/Contents/Resources/bundle';
   $new_dir = File::HomeDir->my_home()
      . '/Library/Containers/com.z2live.battlenations-mac'
      . '/Data/Library/Caches/jujulib/remoteData';
}
elsif ($^O =~ /^MSWin/) {
   my $steam_dir = 'Steam/SteamApps/common/BattleNations/assets';
   $app_dir = "C:/Program Files/$steam_dir";
   $app_dir = "C:/Program Files (x86)/$steam_dir" unless -e $app_dir;
   $new_dir = File::HomeDir->my_home() .
      'Local Settings/Application Data/Z2/Battle Nations/cache/remoteData';
}
else {
   die "Don't know OS $^O";
}

sub update {
   my $date = strftime('%Y-%m-%d-%H-%M', localtime);
   mkdir "data";
   mkdir "data/game";
   mkdir "data/game/$date";

   my %sha1;
   if (open my $SHA1, '<', 'data/game/sha1.txt') {
      while (defined(my $line = <$SHA1>)) {
         $line =~ /^(\w{40}) (.+)/ and $sha1{$1} = $2;
      }
      close $SHA1;
   }
   my $SHA1;

   my $index = "data/game/$date/!index.txt";
   open my $INDEX, '>', $index or die "open: $!";

   print "Checking for updated files\n";
   my %seen;
   foreach my $dir ($new_dir, $app_dir) {
      opendir my $DIR, $dir or die "opendir: $!";
      while (defined(my $file = readdir($DIR))) {
         next if $seen{lc($file)}++;
         my $src = "$dir/$file";
         next unless -f $src;
         my $sha1 = Digest::SHA1->new();
         open my $F, '<', $src or die "open: $!";
         $sha1->addfile($F);
         close($F);
         $sha1 = $sha1->hexdigest();
         my $oldfile = $sha1{$sha1};
         if (!$oldfile) {
            print $file, "\n";
            my $dest = "data/game/$date/$file";
            $file =~ /\.json$/i and copy_json($src, $dest)
               or copy($src, $dest) or die "copy: $!";
            if (!$SHA1) {
               open $SHA1, '>>', 'data/game/sha1.txt' or die "open: $!";
            }
            print $SHA1 "$sha1 $date/$file\n";
            $sha1{$sha1} = $oldfile = $file;
         }
         (my $oldbase = $oldfile) =~ s{^.*/}{};
         $oldfile .= " => $file" unless $file eq $oldbase;
         print $INDEX $oldfile, "\n";
      }
      closedir $DIR;
   }

   close $INDEX;
   if ($SHA1) {
      close $SHA1;
      if (open my $LATEST, '>', 'data/game/latest.txt') {
         print $LATEST $date, "\n";
         close $LATEST;
      }
   }
   elsif (equals_latest($date)) {
      print "none\n";
      unlink $index;
      rmdir  "data/game/$date";
      return 0;
   }
   return 1;
}

sub equals_latest {
   my ($date) = @_;
   open my $F, '<', 'data/game/latest.txt' or return;
   my $latest = <$F>;
   close $F;
   return unless defined $latest;
   chomp($latest);

   open $F, '<', "data/game/$date/!index.txt" or return;
   my @curr = sort <$F>;
   close $F;

   open $F, '<', "data/game/$latest/!index.txt" or return;
   my @latest = sort <$F>;
   close $F;

   return unless @curr == @latest;
   foreach my $i (0 .. $#curr) {
      return unless $curr[$i] eq $latest[$i];
   }
   return 1;
}

sub copy_json {
   my ($src, $dest) = @_;
   open my $IN, '<:encoding(utf8)', $src or return;
   open my $OUT, '>:encoding(utf8)', $dest or return;
   my $json = JSON::XS->new();
   $json->pretty();
   $json->canonical();
   my $ret;
   eval {
      local $/ = undef;
      my $data = $json->decode(<$IN>);
      print $OUT $json->encode($data);
      $ret = 1;
   };
   warn $@ if $@;
   close $IN;
   close $OUT;
   return $ret;
}

sub get {
   my ($class, $file) = @_;
   return "$new_dir/$file" if -f "$new_dir/$file";
   return "$app_dir/$file" if -f "$app_dir/$file";
   return;
}

sub read {
   my ($class, $file, $enc) = @_;
   $enc //= '';
   my $F;
   open $F, "<$enc", "$new_dir/$file"
   or open $F, "<$enc", "$app_dir/$file"
   or die "Can't read $file: $!\n";
   return $F;
}

sub json {
   my ($class, $file) = @_;
   my $F = $class->read($file, ':encoding(utf8)');
   local $/ = undef;
   my $data = decode_json(<$F>);
   scrub($data);
   return $data;
}

sub scrub {
   my $ref = ref($_[0]);
   if ($ref eq 'HASH') {
      scrub($_) foreach values %{$_[0]};
   }
   elsif ($ref eq 'ARRAY') {
      scrub($_) foreach @{$_[0]};
   }
   elsif ($ref eq 'JSON::PP::Boolean' || $ref eq 'JSON::XS::Boolean') {
      $_[0] = ${$_[0]};
   }
}

sub glob {
   my ($class, $pat) = @_;
   return (bsd_glob("$new_dir/$pat", GLOB_NOCASE),
           bsd_glob("$app_dir/$pat", GLOB_NOCASE));
}

1 # end BN::File
