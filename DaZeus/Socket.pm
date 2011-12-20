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
	my $self = {};
	bless $self, $pkg;

	$self->{sock} = IO::Socket::UNIX->new(Peer => $socket, Type => SOCK_STREAM);
	return if(!$self->{sock});

	return $self;
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

	my $sock = $self->{sock};
	my $len = bytes $body;
	print $sock "!msg $network $channel $len\n";
	print $sock $body;
	$sock->flush();
}

1;
