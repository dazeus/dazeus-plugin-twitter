#!/usr/bin/perl

# Copyright (C) 2012  Sjors Gielen <dazeus@sjorsgielen.nl>
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use strict;
use warnings;
use Net::Twitter::Lite::WithAPIv1_1;
use HTML::Entities;
use DaZeus;
use Getopt::Long::Descriptive;

use Data::Dumper;
my $CHANNEL = pop @ARGV;
my $NETWORK = pop @ARGV;
my $LISTID  = pop @ARGV;
my $TWUSER  = pop @ARGV;

my ($opt, $usage) = describe_options(
	"%c <options> <twuser> <twlistid> <network> <channel>",
	[ 'help',		"print usage message and exit" ],
	[ 'interval|i=i',	"interval for Twitter requests", {default => 120} ],
	[ 'quiet|q',		"don't output any warnings" ],
	[ 'verbose|v',		"output every twitter message" ],
	[ 'tweetlim|l',		"number of tweets sent at most at once", {default => 5} ],
	[ 'sock|s=s',		"socket to DaZeus SocketPlugin", {default => 'unix:dazeus.sock'} ],
	[ 'key=s',		"Twitter consumer key" ],
	[ 'secret=s',		"Twitter consumer secret" ],
	[ 'token=s',		"Twitter user access token" ],
	[ 'token_secret=s',	"Twitter user access token secret" ],
);

my $help = $opt->help;
if(!$help && $CHANNEL && $CHANNEL !~ /^#/) {
	warn "Channel does not start with #, did you forget to escape it?\n";
	$help = 1;
}

if($help or !defined $TWUSER or !defined $LISTID or !defined $NETWORK
         or !defined $CHANNEL)
{
	print $usage->text;
	exit;
}

my $QUIET = $opt->verbose ? 0 : $opt->quiet ? 2 : 1;

unless($opt->key && $opt->secret && $opt->token && $opt->token_secret) {
	die "You must give --key, --secret, --token and --token_secret\n";
}

my $net_twitter = new Net::Twitter::Lite::WithAPIv1_1(
	consumer_key => $opt->key,
	consumer_secret => $opt->secret,
	access_token => $opt->token,
	access_token_secret => $opt->token_secret,
	ssl => 1,
);
my $dazeus      = DaZeus->connect($opt->sock);
if(!$dazeus) {
	die $!;
}
my $last_id     = 1;
binmode(STDOUT, ':utf8');

my $first = 1;
while(1) {
	sleep $opt->interval if !$first;
	$first = 0;

	eval {
		my $limit = $net_twitter->rate_limit_status()->{'resources'}{'lists'}{'/lists/statuses'};
		if($limit <= 0) {
			warn "Warning: Rate limit hit, you should decrease your interval (".$opt->interval.")\n"
				unless $QUIET > 1;
			next;
		}
	};
	if($@) {
		warn "Failed to fetch Twitter rate limit: $@\n"
			unless $QUIET > 1;
		next;
	}
	my $statuses;
	eval {
		$statuses = $net_twitter->list_statuses({
			owner_screen_name => $TWUSER,
			slug => $LISTID,
			since_id => $last_id,
			per_page => $opt->tweetlim,
			include_rts => 1,
		});
	};
	if($@) {
		warn "Failed to fetch Twitter statuses: $@\n"
			unless $QUIET > 1;
		next;
	}
	my @statuses = reverse (@$statuses > 5 ? @$statuses[0..4] : @$statuses);
	for my $status(@statuses) {
		my $body = "-Twitter- <" . $status->{user}{screen_name} . "> ";
		if ($status->{retweeted_status}) {
			$body .= "RT @" . $status->{retweeted_status}{user}{screen_name} . ": "
			. decode_entities($status->{retweeted_status}{text});
		} else {
			$body .= decode_entities ($status->{text});
		}
		print "$body\n" unless $QUIET;
		eval {
			my $result = $dazeus->message($NETWORK, $CHANNEL, $body);
		};
		if($@) {
			warn "Failed to inform DaZeus of new Twitter status: $@\n";
		}
		if( $last_id <= $status->{id} ) {
			$last_id = $status->{id};
		}
	}
}

1;
