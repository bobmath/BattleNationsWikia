package MW::UserAgent;
use strict;
use warnings;
use Carp qw( croak );
use Data::Dump qw( dump );
use File::Basename qw( basename );
use JSON::XS qw( decode_json );
use LWP::UserAgent;
use URI;

my $OSX_SECURITY = '/usr/bin/security';
$OSX_SECURITY = undef unless $^O eq 'darwin' && -f $OSX_SECURITY;

sub new {
   my ($class, $uri) = @_;
   croak 'API URI required' unless $uri;
   $uri = URI->new($uri);
   croak 'API URI must be absolute' unless $uri->scheme();
   my $host = $uri->host() or croak 'API URI must include hostname';
   my $ua = LWP::UserAgent->new(cookie_jar => {});
   return bless {
      uri => $uri,
      host => $host,
      ua => $ua,
   } => $class;
}

sub login {
   my ($self) = @_;
   my @user_pass = $self->keychain_user_pass();
   @user_pass = $self->netrc_user_pass() unless @user_pass;
   @user_pass = $self->ask_user_pass() unless @user_pass;
   croak 'Password required to login' unless @user_pass;

   my @args = (
      format => 'json',
      action => 'login',
      lgname => $user_pass[0],
      lgpassword => $user_pass[1],
   );
   my $resp = $self->{ua}->post($self->{uri}, \@args);
   croak 'Login API call failed' unless $resp->is_success();
   my $dat = decode_json($resp->content()) or croak 'API JSON error';
   my $result = $dat->{login}{result} // '';
   if ($result eq 'NeedToken') {
      push @args, lgtoken => $dat->{login}{token} // '';
      $resp = $self->{ua}->post($self->{uri}, \@args);
      croak 'Login API call failed' unless $resp->is_success();
      $dat = decode_json($resp->content()) or croak 'API JSON error';
      $result = $dat->{login}{result} // '';
   }

   if ($result eq 'WrongPass' && $user_pass[2] eq 'keychain') {
      system $OSX_SECURITY, 'delete-internet-password',
         '-a', $user_pass[0], '-s', $self->{host};
   }

   croak "Login failed: $result" . dump($dat)
      unless $result eq 'Success';

   if ($OSX_SECURITY && $user_pass[2] eq 'prompt') {
      system $OSX_SECURITY, 'add-internet-password',
         '-a', $user_pass[0], '-s', $self->{host}, '-w', $user_pass[1];
   }
}

sub keychain_user_pass {
   my ($self) = @_;
   return unless $OSX_SECURITY;
   my $out = `$OSX_SECURITY find-internet-password -s $self->{host} -g 2>&1`
      or return;
   my ($user) = $out =~ /^\s*"acct"<blob>="(.+)"$/m or return;
   my ($pass) = $out =~ /^\s*password:\s*"(.+)"$/m or return;
   return ($user, $pass, 'keychain');
}

sub netrc_user_pass {
   my ($self) = @_;
   require Net::Netrc;
   my $netrc = Net::Netrc->lookup($self->{host}) or return;
   return ($netrc->login(), $netrc->password(), 'netrc');
}

sub ask_user_pass {
   my ($self) = @_;
   require Term::ReadKey;

   my $user = get_line('Username');
   return unless defined $user;

   Term::ReadKey::ReadMode(noecho => \*STDIN);
   my $pass = get_line('Password');
   Term::ReadKey::ReadMode(restore => \*STDIN);
   print "\n";
   return unless defined $pass;

   return ($user, $pass, 'prompt');
}

sub get_line {
   my ($prompt) = @_;
   local $| = 1;
   print $prompt, ': ' if $prompt;
   my $line = <STDIN>;
   return unless defined($line);
   $line =~ s/\s+$//;
   $line =~ s/^\s+//;
   return unless length($line);
   return $line;
}

sub get_info {
   my ($self, $page, @opts) = @_;
   croak 'Page required' unless defined $page;
   my %opts;
   $opts{$_} = 1 foreach @opts;
   my @args = (
      format => 'json',
      action => 'query',
      titles => $page,
   );
   if (delete $opts{text}) {
      push @args, (
         prop => 'info|revisions',
         rvprop => 'content',
         rvlimit => 1,
      );
   }
   else {
      push @args, prop => 'info';
   }
   push @args, intoken => 'edit' if delete $opts{edit};
   croak 'Unknown options: ' . join(', ', sort keys %opts) if %opts;
   my $resp = $self->{ua}->post($self->{uri}, \@args);
   croak 'API call failed' unless $resp->is_success();
   my $dat = decode_json($resp->content()) or croak 'API JSON error';
   $dat = $dat->{query} or return;
   $dat = $dat->{pages} or return;
   return unless keys(%$dat) == 1;
   ($dat) = values(%$dat);
   if (my $revs = $dat->{revisions}) {
      if (my $rev = $revs->[-1]) {
         ($dat->{_text}) = values(%$rev) if keys(%$rev) == 1;
      }
   }
   return $dat;
}

sub edit {
   my ($self, $page, $text, $summary, $token, @opts) = @_;
   croak 'Page required' unless defined $page;
   croak 'Text required' unless defined $text;
   croak 'Token required' unless defined $token;
   my %opts;
   $opts{$_} = 1 foreach @opts;
   my @args = (
      format => 'json',
      action => 'edit',
      title => $page,
      token => $token,
   );
   push @args, summary => $summary if defined $summary;
   if (delete $opts{append}) {
      push @args, appendtext => $text;
   }
   elsif (delete $opts{prepend}) {
      push @args, prependtext => $text;
   }
   else {
      push @args, text => $text;
   }
   if (delete $opts{nocreate}) {
      push @args, nocreate => '';
   }
   elsif (delete $opts{createonly}) {
      push @args, createonly => '';
   }
   croak 'Unknown options: ' . join(', ', sort keys %opts) if %opts;
   my $resp = $self->{ua}->post($self->{uri}, \@args);
   croak 'API edit call failed' unless $resp->is_success();
   my $dat = decode_json($resp->content()) or croak 'API JSON error';
   my $result = $dat->{edit}{result} // '';
   croak "Edit failed: $result " . dump($dat) unless $result eq 'Success';
}

sub upload {
   my ($self, $file, $token, @opts) = @_;
   croak 'File required' unless defined $file;
   croak 'Token required' unless defined $token;
   croak 'File not found' unless -f $file;

   my $dest = ucfirst(basename($file));
   my ($text, $ignore);
   while (@opts) {
      my $opt = shift @opts;
      if ($opt eq 'dest') {
         $dest = shift(@opts) || $dest;
      }
      elsif ($opt eq 'text') {
         $text = shift(@opts);
      }
      elsif ($opt eq 'ignorewarnings') {
         $ignore = 1;
      }
      else {
         croak "Unknown option: $opt";
      }
   }

   my @args = (
       format   => 'json',
       action   => 'upload',
       token    => $token,
       filename => $dest,
       file     => [$file, $dest],
   );
   push @args, text => $text if defined $text;
   push @args, ignorewarnings => '' if $ignore;

   my $resp = $self->{ua}->post($self->{uri},
      Content_Type => 'form-data', Content => \@args);
   croak 'API call failed' unless $resp->is_success();
   my $dat = decode_json($resp->content());
   if (my $warn = $dat->{upload}{warnings}) {
      foreach my $key (sort keys %$warn) {
         warn $key, ": ", dump($warn->{$key}), "\n";
      }
   }
   if ($dat->{upload}{result} ne 'Success') {
      croak 'Upload failed' . dump($dat);
   }
}

1 # end MW::UserAgent
