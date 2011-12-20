#!/usr/bin/perl

# Copyright (C) 2011  Sjors Gielen <dazeus@sjorsgielen.nl>
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
use Net::Twitter::Lite;
use HTML::Entities;
use DaZeus::Socket;
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
	[ 'sock|s=s',		"socket to DaZeus SocketPlugin", {default => 'dazeus.sock'} ],
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

my $net_twitter = new Net::Twitter::Lite();
my $dazeus      = new DaZeus::Socket($opt->sock);
if(!$dazeus) {
	die $!;
}
my $last_id     = 1;

while(1) {
	if($net_twitter->rate_limit_status()->{'remaining_hits'} <= 0) {
		warn "Warning: Rate limit hit, you should decrease your interval (".$opt->interval.")\n"
			unless $QUIET > 1;
	}
	eval {
		my $statuses = $net_twitter->list_statuses({
			user => $TWUSER,
			list_id => $LISTID,
			since_id => $last_id,
			per_page => $opt->tweetlim,
		});
		my @statuses = reverse @$statuses;
		for my $status(@statuses) {
			my $body = "-Twitter- <" . $status->{user}{screen_name}
			           . "> " . decode_entities ($status->{text});
			my $result = $dazeus->say(
				network => $NETWORK,
				channel => $CHANNEL,
				body    => $body,
			);
			print "$body\n" unless $QUIET;
			if( $last_id <= $status->{id} ) {
				$last_id = $status->{id};
			}
		}
	};
	if( $@ )
	{
		warn("Warning: Could not fetch Tweets: $@") unless $QUIET > 1;
	}
	sleep $opt->interval;
}

1;