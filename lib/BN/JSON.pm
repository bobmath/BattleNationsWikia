package BN::JSON;
use strict;
use warnings;
use JSON::XS qw( decode_json );

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
   my ($class, $file) = @_;
   my $F;
   open $F, '<:encoding(utf8)', "$new_dir/$file"
   or open $F, '<:encoding(utf8)', "$app_dir/$file"
   or die "Can't read $file";
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

1 # end BN::JSON
