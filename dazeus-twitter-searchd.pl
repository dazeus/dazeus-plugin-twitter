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
use Net::Twitter::Lite;
use HTML::Entities;
use DaZeus::Socket;
use Getopt::Long::Descriptive;

use Data::Dumper;
my $CHANNEL = pop @ARGV;
my $NETWORK = pop @ARGV;
my $WORDS   = pop @ARGV;

my ($opt, $usage) = describe_options(
	"%c <options> <comma separated words> <network> <channel>",
	[ 'help',		"print usage message and exit" ],
	[ 'interval|i=i',	"interval for Twitter requests", {default => 120} ],
	[ 'quiet|q',		"don't output any warnings" ],
	[ 'verbose|v',		"output every twitter message" ],
	[ 'tweetlim|l',		"number of tweets sent at most at once", {default => 5} ],
	[ 'sock|s=s',		"socket to DaZeus SocketPlugin", {default => 'dazeus.sock'} ],
        [ 'separator|p=s',	"Separator for words (default is comma)", {default => ','} ],
);

my $help = $opt->help;
if(!$help && $CHANNEL && $CHANNEL !~ /^#/) {
	warn "Channel does not start with #, did you forget to escape it?\n";
	$help = 1;
}

if($help or !defined $WORDS or !defined $NETWORK
         or !defined $CHANNEL)
{
	print $usage->text;
	exit;
}

my $QUIET = $opt->verbose ? 0 : $opt->quiet ? 2 : 1;
my $separator = $opt->separator;
my @words = split /\Q$separator\E/, $WORDS;

print "Searching for words:\n'" . join("', '", @words) . "'\n";

my $net_twitter = new Net::Twitter::Lite();
my $dazeus      = new DaZeus::Socket($opt->sock);
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
		my $rate = $net_twitter->rate_limit_status();
		if($rate->{'remaining_hits'} <= 0) {
			return 0 if $QUIET;
			die "Warning: Rate limit hit, you should decrease your interval (".$opt->interval.")\n"
				. Dumper($rate);
		}
	};
	if($@) {
		warn "Failed to fetch Twitter rate limit: $@\n"
			unless $QUIET > 1;
		next;
	}
	my @tweets;
	eval {
		foreach(@words) {
			my $r = $net_twitter->search({q=>$_,since_id=>$last_id});
			push @tweets, @{$r->{'results'}};
		}
	};
	if($@) {
		warn "Failed to fetch Twitter statuses: $@\n"
			unless $QUIET > 1;
		next;
	}
	@tweets = sort {$b->{'id'} <=> $a->{'id'}} @tweets;
	if(@tweets > $opt->tweetlim) {
		@tweets = @tweets[0..$opt->tweetlim - 1];
	}
	for my $status(@tweets) {
		my $body = "-Twitter- <" . $status->{from_user}
			   . "> " . decode_entities ($status->{text});
		print "$body\n" unless $QUIET;
		eval {
			my $result = $dazeus->say(
				network => $NETWORK,
				channel => $CHANNEL,
				body    => $body,
			);
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
