package DaZeus::Socket;
use strict;
use warnings;
use IO::Socket::UNIX;

sub bytes($) {
	use bytes;
	return length shift;
}

sub new {
	my ($pkg, $socket) = @_;
	my $self = {socketfile => $socket};
	bless $self, $pkg;

	return $self;
}

sub connect {
	my $self = shift;
	if($self->{sock}) {
		return;
	}
	$self->{sock} = IO::Socket::UNIX->new(Peer => $self->{'socketfile'}, Type => SOCK_STREAM);
	if(!$self->{sock}) {
		warn "Failed to connect: $!\n";
		return;
	}
	binmode($self->{sock}, ':utf8');
}

sub say {
	my ($self, %args) = @_;
	my $network = delete $args{'network'};
	my $channel = delete $args{'channel'};
	my $body    = delete $args{'body'};
	foreach(keys %args) {
		warn "DaZeus::Socket::say() ignored key $_\n";
		return;
	}
	if(!$network || !$channel || !$body) {
		warn "DaZeus::Socket::say() requires network, channel and body\n";
		return;
	}

	$self->connect();
	my $sock = $self->{sock};
	if(!$sock) {
		warn "DaZeus::Socket::say() couldn't connect\n";
		return;
	}
	my $len = bytes $body;
	print $sock "!msg $network $channel $len\n";
	print $sock $body;
	$sock->flush();
}

1;
