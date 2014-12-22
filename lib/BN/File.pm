package BN::File;
use strict;
use warnings;
use Digest::SHA1 ();
use File::Copy qw( copy );
use File::HomeDir ();
use JSON::XS qw( decode_json );
use POSIX qw( strftime );

my ($app_dir, $new_dir, $promo_dir, %file_index);
if ($^O eq 'darwin') {
   $app_dir = '/Applications/BattleNations.app/Contents/Resources/bundle';
   my $cache_dir = File::HomeDir->my_home()
      . '/Library/Containers/com.z2live.battlenations-mac/Data/Library/Caches';
   $new_dir = $cache_dir . '/jujulib/remoteData';
   $promo_dir = $cache_dir . '/com.z2live.battlenations-mac';
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

sub promos {
   my ($class) = @_;
   eval {
      require DBI;
      my $dbh = DBI->connect("dbi:SQLite:dbname=$promo_dir/Cache.db",
         "", "") or die "Can't read Cache.db";
      mkdir 'data';
      mkdir 'data/game';
      mkdir 'data/game/promos';
      my $cache = $dbh->selectall_arrayref(q[
         select request_key, receiver_data
         from cfurl_cache_receiver_data
         inner join cfurl_cache_response
         on cfurl_cache_receiver_data.entry_id = cfurl_cache_response.entry_id
         where isDataOnFS == 1
      ]) or die;
      my $promodir = 'data/game/promos';
      my $logfile = "$promodir/!index.txt";
      my %seen;
      if (open my $LOG, '<', $logfile) {
         while (<$LOG>) {
            chomp;
            $seen{$_}++;
         }
         close $LOG;
      }
      open my $LOG, '>>', $logfile or die "Can't write $logfile";;
      foreach my $entry (sort { $a->[0] cmp $b->[0] } @$cache) {
         my $url = $entry->[0];
         next if $seen{$url};
         print $LOG $url, "\n";
         (my $file = $url) =~ s{^.*/}{} or next;
         my $path = "$promodir/$file";
         next if -e $path;
         print $file, "\n";
         copy "$promo_dir/fsCachedData/$entry->[1]", $path or die;
      }
      close $LOG;
      $dbh->disconnect();
   };
   warn $@ if $@;
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
   }
   elsif (equals_latest($date)) {
      print "none\n";
      unlink $index;
      rmdir  "data/game/$date";
      return 0;
   }
   if (open my $LATEST, '>', 'data/game/latest.txt') {
      print $LATEST $date, "\n";
      close $LATEST;
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
   my @latest = <$F>;
   for (@latest) {
      $_ = "$latest/$_" unless m{/};
   }
   @latest = sort @latest;
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

sub set_date {
   my ($class, $date) = @_;
   open my $INDEX, '<', "data/game/$date/!index.txt"
      or die "Can't read game dir $date: $!\n";
   while (defined(my $line = <$INDEX>)) {
      chomp $line;
      my $dir = $line =~ s{^(.*?)/}{} ? $1 : $date;
      my $file = $line =~ s{ => (.*)}{} ? $1 : $line;
      $file_index{lc($file)} = "data/game/$dir/$line";
   }
   close $INDEX;
}

sub get {
   my ($class, $file) = @_;
   if (%file_index) {
      return $file_index{lc($file)};
   }
   return "$new_dir/$file" if -f "$new_dir/$file";
   return "$app_dir/$file" if -f "$app_dir/$file";
   return;
}

sub read {
   my ($class, $file, $enc) = @_;
   $enc //= '';
   my $F;
   if (%file_index) {
      my $path = $file_index{lc($file)} or die "No such file: $file\n";
      open $F, "<$enc", $path or die "Can't read $path: $!\n";
   }
   else {
      open $F, "<$enc", "$new_dir/$file"
      or open $F, "<$enc", "$app_dir/$file"
      or die "Can't read $file: $!\n";
   }
   return $F;
}

sub json {
   my ($class, $file) = @_;
   my $F = $class->read($file, ':raw');
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

1 # end BN::File
