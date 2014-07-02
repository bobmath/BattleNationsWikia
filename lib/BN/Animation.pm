package BN::Animation;
use strict;
use warnings;

my %index;
sub build_index {
   my $packs = BN::File->json('AnimationPacks.json');
   foreach my $pack (@{$packs->{animationPacks}}) {
      my $meta = BN::File->json($pack . '_Metadata.json');
      foreach my $name (@{$meta->{animationNames}}) {
         $index{lc($name)} = $pack;
      }
   }
}

my %animations;
sub get {
   my ($class, $key) = @_;
   return unless $key;
   $key = lc($key);
   return $animations{$key} if $animations{$key};
   build_index() unless %index;
   $class->read_pack($index{$key});
   return $animations{$key};
}

BN->simple_accessor('tag');

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
   $anim->{_tag} = $tag;
   $animations{lc($tag)} = $anim;
   my $scale = $ver > 4 ? 1/32 : 1;

   my $alen = 0;
   if ($ver >= 8) {
      my $flags = read_short($F);
      if    ($flags == 0)     { $alen = 0 }
      elsif ($flags == 1)     { $alen = 1 }
      elsif ($flags == 0x101) { $alen = 4 }
      else { die 'Unknown animation flags' }
   }

   my @points;
   for (1 .. $num_points) {
      my %point;
      $point{x1} = read_short($F) * $scale;
      $point{y1} = read_short($F) * $scale;
      read_short($F) if $ver == 4;
      $point{x2} = read_short($F);
      $point{y2} = read_short($F);
      my $alpha = 1;
      for (1 .. $alen) {
         my $a = read_float($F);
         $alpha = $a if $a < $alpha;
      }
      $point{a} = $alpha;
      push @points, \%point;
   }
   $anim->{points} = \@points;

   $anim->{xmin} = read_short($F) * $scale;
   $anim->{xmax} = read_short($F) * $scale;
   $anim->{ymin} = read_short($F) * $scale;
   $anim->{ymax} = read_short($F) * $scale;

   my $num_frames = read_unpack($F, 2, 'v');
   my @frames;
   for (1 .. $num_frames) {
      my $len = read_short($F);
      read_byte($F) if $ver > 4;
      push @frames, [ read_unpack($F, $len*2, 'v*') ];
   }
   $anim->{frames} = \@frames;

   if ($ver == 4) {
      $anim->{sequence} = [ 0 .. $num_frames - 1 ];
   }
   else {
      my $len = read_unpack($F, 4, 'v');
      $anim->{sequence} = [ read_unpack($F, $len*2, 'v*') ];
   }

   return $anim;
}

sub read_byte {
   my ($F) = @_;
   my $c = getc($F);
   die 'hit EOF' unless defined $c;
   return ord($c);
}

sub read_short {
   my ($F) = @_;
   my $buf;
   my $count = read($F, $buf, 2) or die 'read error';
   die 'hit EOF' unless $count == 2;
   return unpack 's<', $buf;
}

sub read_float {
   my ($F) = @_;
   my $buf;
   my $count = read($F, $buf, 4) or die 'read error';
   die 'hit EOF' unless $count == 4;
   return unpack 'f<', $buf;
}

sub read_unpack {
   my ($F, $len, $pat) = @_;
   return unless $len;
   die 'bad length' if $len < 0;
   my $buf;
   my $count = read($F, $buf, $len) or die 'read error';
   die 'hit EOF' unless $count == $len;
   return unpack $pat, $buf;
}

sub num_frames {
   my ($anim) = @_;
   return scalar @{$anim->{sequence}};
}

sub render {
   my ($anim, $ctx, @args) = @_;
   my $source = $anim->bitmap()->cairo_surface();
   foreach my $quad ($anim->frame(@args)) {
      $ctx->save();
      $ctx->transform(Cairo::Matrix->init(@{$quad->{mat}}));
      $ctx->set_source_surface($source, 0, 0);
      $ctx->move_to($quad->{x0}, $quad->{y0});
      $ctx->line_to($quad->{x1}, $quad->{y1});
      $ctx->line_to($quad->{x2}, $quad->{y2});
      $ctx->line_to($quad->{x3}, $quad->{y3});
      $ctx->close_path();
      if ($quad->{a} < 1) {
         $ctx->clip();
         $ctx->paint_with_alpha($quad->{a});
      }
      else {
         $ctx->fill();
      }
      $ctx->restore();
   }
}

sub frame {
   my ($anim, $num) = @_;
   defined($num = $anim->{sequence}[$num || 0]) or return;
   my $frame = $anim->{frames}[$num] or return;
   die 'Unexpected frame size' if @$frame % 6;
   my $points = $anim->{points};
   my $bitmap = $anim->bitmap();
   my $xscale = ($bitmap->width() - 1) / 0x7fff;
   my $yscale = ($bitmap->height() - 1) / 0x7fff;

   my @quads;
   for (my $i = 0; $i < @$frame; $i += 6) {
      die 'Unexpected frame arrangement' unless $frame->[$i+3] == $frame->[$i]
         && $frame->[$i+4] == $frame->[$i+2];
      my $p0 = $points->[$frame->[$i]];
      my $p1 = $points->[$frame->[$i+1]];
      my $p2 = $points->[$frame->[$i+2]];
      my $p3 = $points->[$frame->[$i+5]];
      my %q;
      $q{a} = $p0->{a} or next;

      $q{x0} = $p0->{x2} * $xscale;  $q{y0} = $p0->{y2} * $yscale;
      $q{x1} = $p1->{x2} * $xscale;  $q{y1} = $p1->{y2} * $yscale;
      $q{x2} = $p2->{x2} * $xscale;  $q{y2} = $p2->{y2} * $yscale;
      $q{x3} = $p3->{x2} * $xscale;  $q{y3} = $p3->{y2} * $yscale;
      my $m11 = $q{x1} - $q{x0};  my $m12 = $q{x2} - $q{x0};
      my $m21 = $q{y1} - $q{y0};  my $m22 = $q{y2} - $q{y0};
      my $d = $m11 * $m22 - $m12 * $m21;
      die 'bad transform' if abs($d) < 1e-6;

      $q{X0} = $p0->{x1};  $q{Y0} = $p0->{y1};
      $q{X1} = $p1->{x1};  $q{Y1} = $p1->{y1};
      $q{X2} = $p2->{x1};  $q{Y2} = $p2->{y1};
      $q{X3} = $p3->{x1};  $q{Y3} = $p3->{y1};
      my $M11 = $q{X1} - $q{X0};  my $M12 = $q{X2} - $q{X0};
      my $M21 = $q{Y1} - $q{Y0};  my $M22 = $q{Y2} - $q{Y0};

      my $a11 = ($M11*$m22 - $M12*$m21) / $d;
      my $a21 = ($M21*$m22 - $M22*$m21) / $d;
      my $a12 = ($M12*$m11 - $M11*$m12) / $d;
      my $a22 = ($M22*$m11 - $M21*$m12) / $d;
      my $a13 = $q{X0} - $a11*$q{x0} - $a12*$q{y0};
      my $a23 = $q{Y0} - $a21*$q{x0} - $a22*$q{y0};
      $q{mat} = [ $a11, $a21, $a12, $a22, $a13, $a23 ];

      push @quads, \%q;
   }

   return @quads;
}

sub box {
   my ($anim, $num) = @_;
   return ($anim->{xmin}, $anim->{xmax}, $anim->{ymin}, $anim->{ymax})
      unless defined $num;
   defined($num = $anim->{sequence}[$num]) or return;
   my $frame = $anim->{frames}[$num] or return;
   my $points = $anim->{points};
   my ($xmin, $xmax, $ymin, $ymax);
   my $p = $points->[$frame->[0]] or return;
   $xmin = $xmax = $p->{x1};
   $ymin = $ymax = $p->{y1};
   foreach my $i (1 .. $#$frame) {
      $p = $points->[$frame->[$i]];
      next if $p->{a} < 0.5 / 255;
      $xmin = $p->{x1} if $p->{x1} < $xmin;
      $xmax = $p->{x1} if $p->{x1} > $xmax;
      $ymin = $p->{y1} if $p->{y1} < $ymin;
      $ymax = $p->{y1} if $p->{y1} > $ymax;
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
