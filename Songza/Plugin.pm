package Plugins::Songza::Plugin;

# SqueezeCenter Copyright 2001-2007 Logitech.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2.

use strict;
use warnings;
use base qw(Slim::Plugin::OPMLBased);

use Plugins::Songza::Settings;
use Scalar::Util qw(blessed);
use Slim::Control::Request;
use Slim::Utils::Prefs;
use Slim::Utils::Log;
use Slim::Utils::Cache;
use Slim::Utils::Strings qw(string);

#use Plugins::GoogleMusic::GoogleAPI qw($googleapi);
use Plugins::Songza::ProtocolHandler;
#use Plugins::GoogleMusic::Image;

# TODO: move these constants to the configurable settings?
# Note: these constants can't be passed to the python API
use Readonly;
Readonly my $MAX_RECENT_ITEMS => 50;
Readonly my $RECENT_CACHE_TTL => 'never';

my %recent_searches;
tie %recent_searches, 'Tie::Cache::LRU', $MAX_RECENT_ITEMS;

my $cache = Slim::Utils::Cache->new('songza', 3);

my $log;
my $prefs = preferences('plugin.songza');


BEGIN {
	$log = Slim::Utils::Log->addLogCategory({
		'category'     => 'plugin.songza',
		'defaultLevel' => 'WARN',
		'description'  => string('PLUGIN_SONGZA'),
	});
}

sub getDisplayName {
	return 'PLUGIN_SONGZA';
}

sub initPlugin {
	my $class = shift;

	$class->SUPER::initPlugin(
		tag    => 'songza',
		feed   => \&toplevel,
		is_app => 1,
		weight => 1,
	);

	if (main::WEBUI) {
		Plugins::Songza::Settings->new;
	}



	return;
}

sub shutdownPlugin {

	return;
}

sub toplevel {
        my ($client, $callback, $args) = @_;

        my @menu = (
                { name  => string('PLUGIN_SONGZA_GO'), type => 'link', url => \&Plugins::Songza::Go }
        );

        $callback->(\@menu);
}



sub my_music {

	return;
}

sub reload_library {

	return;
}

sub all_access {

	return;
}

sub _show_playlist {

	return $menu;
}

sub _playlists {

	return;
}

sub search {

	return;
}

sub search_all_access {

	return;
}


sub add_recent_search {

	return;
}

sub recent_searches {

	return;
}

sub _show_track {

	return $menu;
}

sub _tracks {

	return;
}

sub _tracks_for_album {

	return;
}

sub _show_album {
	return;
}

sub _albums {

	return;
}

sub _show_menu_for_artist {
	return;
}

sub _show_artist {
	return;
}

sub _artists {
	return;
}


1;
