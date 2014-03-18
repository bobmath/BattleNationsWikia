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

my %animations;
sub get {
   my ($class, $key) = @_;
   return unless $key;
   return $animations{$key} if $animations{$key};
   build_index() unless %index;
   $class->read_pack($index{$key});
   return $animations{$key};
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
   $animations{$tag} = $anim;

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
   else {
      die 'Unknown data size';
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

sub num_frames {
   my ($anim) = @_;
   return scalar @{$anim->{frames}};
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

   my $bitmap = $anim->bitmap();
   my $xscale = $bitmap->width() / 0x7fff;
   my $yscale = $bitmap->height() / 0x7fff;

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

sub bitmap {
   my ($anim) = @_;
   return BN::Animation::Bitmap->get($anim->{_pack});
}

package BN::Animation::Bitmap;

my %bitmaps;
sub get {
   my ($class, $key) = @_;
   return unless $key;
   return $bitmaps{$key} ||= bless { _pack=>$key }, $class;
}

sub width {
   my ($bmp) = @_;
   $bmp->read_header() unless exists $bmp->{_width};
   return $bmp->{_width};
}

sub height {
   my ($bmp) = @_;
   $bmp->read_header() unless exists $bmp->{_height};
   return $bmp->{_height};
}

sub read_header {
   my ($bmp) = @_;
   my $F = BN::File->read($bmp->{_pack} . '_0.z2raw', ':raw');
   my ($ver, $wid, $hgt, $bits) =
      BN::Animation::read_unpack($F, 16, 'V*');
   die 'Bad bitmap version' if $ver > 1;
   die 'Bad bitmap depth' unless $bits == 4 || $bits == 8;
   $bmp->{_version} = $ver;
   $bmp->{_width} = $wid;
   $bmp->{_height} = $hgt;
   $bmp->{_bits} = $bits;
   return $F;
}

sub write_pam {
   my ($bmp, $file) = @_;
   my $data = $bmp->bitmap_data('rgba');
   open my $F, '>:raw', $file or die "Can't write $file: $!\n";
   print $F "P7\nWIDTH $bmp->{_width}\nHEIGHT $bmp->{_height}\n",
      "DEPTH 4\nMAXVAL 255\nTUPLTYPE RGB_ALPHA\nENDHDR\n";
   print $F $data;
   close $F;
}

sub cairo_surface {
   my ($bmp) = @_;
   return $bmp->{cairo_surf} if $bmp->{cairo_surf};
   $bmp->{cairo_data} = $bmp->bitmap_data('cairo');
   return $bmp->{cairo_surf} = Cairo::ImageSurface->create_for_data(
      $bmp->{cairo_data}, 'argb32', $bmp->{_width}, $bmp->{_height},
      $bmp->{_stride});
}

sub free {
   my ($bmp) = @_;
   $bmp->{cairo_surf} = undef;
   $bmp->{cairo_data} = undef;
}

sub bitmap_data {
   my ($bmp, $format) = @_;
   my $F = $bmp->read_header();
   my $wid = $bmp->{_width};
   my $hgt = $bmp->{_height};
   my $bits = $bmp->{_bits};
   my $pad = '';
   $format ||= 'rgba';
   if ($format eq 'cairo') {
      require Cairo;
      $bmp->{_stride} = Cairo::Format::stride_for_width('argb32', $wid);
      $pad = "\0" x ($wid * 4 - $bmp->{_stride});
   }

   my $dat = '';
   if ($bmp->{_version} == 0) {
      for my $y (1 .. $hgt) {
         for my $x (1 .. $wid) {
            $dat .= read_pix($F, $bits, $format);
         }
         $dat .= $pad;
      }
   }
   else {
      my ($len, $pal_size) = BN::Animation::read_unpack($F, 8, 'V*');
      die 'Bad palette size' if $pal_size < 1 || $pal_size > 0x100;
      my @pal;
      push @pal, read_pix($F, $bits, $format) for 1 .. $pal_size;
      my $x = 0;
      my $y = 0;
      while ($y < $hgt) {
         my $c = getc($F);
         die 'Hit EOF' unless defined($c);
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
   die 'Hit EOF' unless defined($c);
   $c = ord($c);
   die 'Bad pixel' if $c >= @$pal;
   return $pal->[$c];
}

sub read_pix {
   my ($F, $bits, $format) = @_;
   my ($r, $g, $b, $a, $buf);
   if ($bits == 4) {
      my $count = read $F, $buf, 2 or die "Read error: $!";
      die 'Hit EOF' unless $count == 2;
      my $p = unpack('v', $buf);
      $r = (($p >> 12) & 0xf) * 0x11;
      $g = (($p >> 8) & 0xf) * 0x11;
      $b = (($p >> 4) & 0xf) * 0x11;
      $a = ($p & 0xf) * 0x11;
   }
   else {
      my $count = read $F, $buf, 4 or die "Read error: $!";
      die 'Hit EOF' unless $count == 4;
      return $buf unless $format eq 'cairo';
      ($r, $g, $b, $a) = unpack 'C*', $buf;
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

1 # end BN::Animation::Bitmap
