package BN::Animation;
use strict;
use warnings;

my %index;
sub build_index {
   my $packs = BN::File->json('AnimationPacks.json');
   foreach my $pack (@{$packs->{animationPacks}}) {
      my $meta = BN::File->json($pack . '_Metadata.json');
      foreach my $name (@{$meta->{animationNames}}) {
         $index{$name} = $pack;
      }
   }
}

sub get {
   my ($class, $key) = @_;
   return unless $key;
   build_index() unless %index;
   my @anims = $class->read_pack($index{$key});
   foreach my $anim (@anims) {
      return $anim if $anim->{_tag} eq $key;
   }
   return;
}

sub read_pack {
   my ($class, $pack) = @_;
   return unless $pack;
   my $F = BN::File->read($pack . '_Timeline.bin', ':raw');
   my @anims;
   my ($ver, $num) = read_unpack($F, 7, 'vxv');
   die 'unknown version' unless $ver == 4 || $ver == 6 || $ver == 8;
   for my $n (1 .. $num) {
      push @anims, $class->read_anim($F, $pack, $ver);
   }
   close $F;
   return @anims;
}

sub read_anim {
   my ($class, $F, $pack, $ver) = @_;
   my $anim = { _pack=>$pack, _ver=>$ver };
   bless $anim, $class;
   my ($tag, $num_points) = read_unpack($F, 0x104, 'Z256x2v');
   die 'Invalid animation name' if $tag =~ /\W/;
   $anim->{_tag} = $tag;

   my $point_size;
   if ($ver == 4) {
      $point_size = 10;
   }
   elsif ($ver == 6) {
      $point_size = 8;
   }
   elsif ($ver == 8) {
      my $flags = read_unpack($F, 2, 'v');
      if    ($flags == 0)     { $point_size = 8 }
      elsif ($flags == 1)     { $point_size = 12 }
      elsif ($flags == 0x101) { $point_size = 24 }
      else { die 'Unknown animation flags' }
   }

   my @points;
   for (1 .. $num_points) {
      my @point = read_unpack($F, $point_size, 's<*');
      splice @point, 2, 1 if $ver == 4;
      push @points, \@point;
   }
   $anim->{points} = \@points;

   $anim->{box} = [ read_unpack($F, 8, 's<*') ];

   my $num_frames = read_unpack($F, 2, 'v');
   my @frames;
   for (1 .. $num_frames) {
      my $len = read_unpack($F, ($ver == 4 ? 2 : 3), 'v');
      push @frames, [ read_unpack($F, $len*2, 'v*') ];
   }
   $anim->{frames} = \@frames;

   my @sequence;
   if ($ver == 4) {
      @sequence = 0 .. $num_frames - 1;
   }
   else {
      my $len = read_unpack($F, 4, 'v');
      @sequence = read_unpack($F, $len*2, 'v*');
   }
   $anim->{sequence} = \@sequence;

   return $anim;
}

sub read_unpack {
   my ($F, $len, $pat) = @_;
   return unless $len;
   my $buf;
   my $count = read($F, $buf, $len) or die 'read error';
   die 'hit EOF' unless $count == $len;
   return unpack $pat, $buf;
}

sub frame {
   my ($anim, $num, $size, $center, $boxframe) = @_;
   my $frame = $anim->{frames}[$num || 0] or return;
   die 'Unexpected frame size' if @$frame % 6;
   my $points = $anim->{points};
   my @box = $anim->box($boxframe);

   my $scale = 1;
   if ($size) {
      my $wid = $box[1] - $box[0];
      my $hgt = $box[3] - $box[2];
      $scale = $size / ($wid >= $hgt ? $wid : $hgt);
   }

   my $xoff = 0;
   my $yoff = 0;
   if ($center) {
      $xoff = ($box[0] + $box[1]) / 2;
      $yoff = ($box[3] + $box[2]) / 2;
   }

   my $xscale = $anim->bmp_width() / 0x7fff;
   my $yscale = $anim->bmp_height() / 0x7fff;

   my @quads;
   for (my $i = 0; $i < @$frame; $i += 6) {
      die 'Unexpected frame arrangement' unless $frame->[$i+3] == $frame->[$i]
         && $frame->[$i+4] == $frame->[$i+2];
      my $p0 = $points->[$frame->[$i]];
      my $p1 = $points->[$frame->[$i+1]];
      my $p2 = $points->[$frame->[$i+2]];
      my $p3 = $points->[$frame->[$i+5]];
      my %q;

      $q{x0} = $p0->[2] * $xscale;  $q{y0} = $p0->[3] * $yscale;
      $q{x1} = $p1->[2] * $xscale;  $q{y1} = $p1->[3] * $yscale;
      $q{x2} = $p2->[2] * $xscale;  $q{y2} = $p2->[3] * $yscale;
      $q{x3} = $p3->[2] * $xscale;  $q{y3} = $p3->[3] * $yscale;
      my $m11 = $q{x1} - $q{x0};  my $m12 = $q{x2} - $q{x0};
      my $m21 = $q{y1} - $q{y0};  my $m22 = $q{y2} - $q{y0};
      my $d = $m11 * $m22 - $m12 * $m21;

      $q{X0} = ($p0->[0]-$xoff) * $scale;  $q{Y0} = ($p0->[1]-$yoff) * $scale;
      $q{X1} = ($p1->[0]-$xoff) * $scale;  $q{Y1} = ($p1->[1]-$yoff) * $scale;
      $q{X2} = ($p2->[0]-$xoff) * $scale;  $q{Y2} = ($p2->[1]-$yoff) * $scale;
      $q{X3} = ($p3->[0]-$xoff) * $scale;  $q{Y3} = ($p3->[1]-$yoff) * $scale;
      my $M11 = $q{X1} - $q{X0};  my $M12 = $q{X2} - $q{X0};
      my $M21 = $q{Y1} - $q{Y0};  my $M22 = $q{Y2} - $q{Y0};

      my $a11 = ($M11*$m22 - $M12*$m21) / $d;
      my $a21 = ($M21*$m22 - $M22*$m21) / $d;
      my $a12 = ($M12*$m11 - $M11*$m12) / $d;
      my $a22 = ($M22*$m11 - $M21*$m12) / $d;
      my $a13 = $q{X0} - $a11*$q{x0} - $a12*$q{y0};
      my $a23 = $q{Y0} - $a21*$q{x0} - $a22*$q{y0};
      $q{mat} = [ $a11, $a21, $a12, $a22, $a13, $a23 ];
      $q{det} = $a11*$a22 - $a12*$a21;

      push @quads, \%q;
   }
   return @quads;
}

sub sequence {
   my ($anim) = @_;
   return @{$anim->{sequence}};
}

sub box {
   my ($anim, $frame_num) = @_;
   my $frame;
   $frame = $anim->{frames}[$frame_num] if defined $frame_num;
   return @{$anim->{box}} unless $frame;
   my $points = $anim->{points};
   my ($xmin, $xmax, $ymin, $ymax);
   my $p = $points->[$frame->[0]];
   $xmin = $xmax = $p->[0];
   $ymin = $ymax = $p->[1];
   foreach my $i (1 .. $#$frame) {
      $p = $points->[$frame->[$i]];
      $xmin = $p->[0] if $p->[0] < $xmin;
      $xmax = $p->[0] if $p->[0] > $xmax;
      $ymin = $p->[1] if $p->[1] < $ymin;
      $ymax = $p->[1] if $p->[1] > $ymax;
   }
   return ($xmin, $xmax, $ymin, $ymax);
}

BN->multi_accessor('bmp_width', 'bmp_height' => sub {
   my ($anim) = @_;
   my $F = BN::File->read($anim->{_pack} . '_0.z2raw', ':raw');
   my ($ver, $wid, $hgt, $bits) = read_unpack($F, 16, 'V*');
   close $F;
   die 'Bad bitmap version' if $ver > 1;
   die 'Bad bitmap depth' unless $bits == 4 || $bits == 8;
   return ($wid, $hgt);
});

sub bitmap {
   my ($anim, $format, $stride) = @_;
   my $F = BN::File->read($anim->{_pack} . '_0.z2raw', ':raw');
   my ($ver, $wid, $hgt, $bits) = read_unpack($F, 16, 'V*');
   die 'Bad bitmap version' if $ver > 1;
   die 'Bad bitmap depth' unless $bits == 4 || $bits == 8;
   $format ||= 'rgba';
   $stride ||= $wid * 4;
   my $pad = "\0" x ($wid * 4 - $stride);

   my $dat = '';
   if ($ver == 0) {
      for my $y (1 .. $hgt) {
         for my $x (1 .. $wid) {
            $dat .= read_pix($F, $bits, $format);
         }
         $dat .= $pad;
      }
   }
   else {
      my ($len, $pal_size) = read_unpack($F, 8, 'V*');
      die 'Bad palette size' if $pal_size < 1 || $pal_size > 0x100;
      my @pal;
      push @pal, read_pix($F, $bits, $format) for 1 .. $pal_size;
      my $x = 0;
      my $y = 0;
      while ($y < $hgt) {
         my $c = getc($F);
         die 'hit EOF' unless defined($c);
         $c = ord($c);
         my $num = ($c >> 1) + 1;
         if ($c & 1) {
            my $pix = read_pal_pix($F, \@pal);
            for (1 .. $num) {
               $dat .= $pix;
               if (++$x >= $wid) { $x = 0; $y++; $dat .= $pad; }
            }
         }
         else {
            for (1 .. $num) {
               $dat .= read_pal_pix($F, \@pal);
               if (++$x >= $wid) { $x = 0; $y++; $dat .= $pad; }
            }
         }
      }
      die 'Corrupt bitmap' unless tell($F) == $len + 20;
   }
   close $F;
   return $dat;
}

sub read_pal_pix {
   my ($F, $pal) = @_;
   my $c = getc($F);
   die 'hit EOF' unless defined($c);
   $c = ord($c);
   die 'bad pixel' if $c >= @$pal;
   return $pal->[$c];
}

sub read_pix {
   my ($F, $bits, $format) = @_;
   my ($r, $g, $b, $a);

   if ($bits == 4) {
      my $p = read_unpack($F, 2, 'v');
      $r = (($p >> 12) & 0xf) * 0x11;
      $g = (($p >> 8) & 0xf) * 0x11;
      $b = (($p >> 4) & 0xf) * 0x11;
      $a = ($p & 0xf) * 0x11;
   }
   else {
      ($r, $g, $b, $a) = read_unpack($F, 4, 'C*');
   }

   if ($format eq 'cairo') {
      if ($a < 0xff) {
         my $s = $a / 0xff;
         $r = int($r * $s);
         $g = int($g * $s);
         $b = int($b * $s);
      }
      return pack 'L', ($a << 24) | ($r << 16) | ($g << 8) | $b;
   }
   return chr($r) . chr($g) . chr($b) . chr($a);
}

1 # end BN::Animation
