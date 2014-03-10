package BN::File;
use strict;
use warnings;
use JSON::XS qw( decode_json );
use File::Glob qw( bsd_glob GLOB_NOCASE );

my ($app_dir, $new_dir);
if ($^O eq 'darwin') {
   $app_dir = '/Applications/BattleNations.app/Contents/Resources/bundle';
   my $user_dir = (getpwuid $<)[7] or die 'User dir not found';
   $new_dir = $user_dir . '/Library/Containers/com.z2live.battlenations-mac/Data/Library/Caches/jujulib/remoteData';
}
else {
   die "Don't know OS $^O";
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
   elsif ($ref eq 'JSON::PP::Boolean') {
      $_[0] = ${$_[0]};
   }
}

sub glob {
   my ($class, $pat) = @_;
   return (bsd_glob("$new_dir/$pat", GLOB_NOCASE),
           bsd_glob("$app_dir/$pat", GLOB_NOCASE));
}

1 # end BN::File
