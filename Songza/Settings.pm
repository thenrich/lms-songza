package Plugins::Songza::Settings;

# SqueezeCenter Copyright 2001-2007 Logitech.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2.

use strict;
use warnings;
use base qw(Slim::Web::Settings);

use Slim::Utils::Log;
use Slim::Utils::Misc;
use Slim::Utils::Strings qw(string);
use Slim::Utils::Prefs;

#use Plugins::GoogleMusic::GoogleAPI qw($googleapi);

my $log = logger('plugin.songza');
my $prefs = preferences('plugin.songza');

sub name {
	return Slim::Web::HTTP::CSRF->protectName('PLUGIN_SONGZA');
}

sub page {
	return Slim::Web::HTTP::CSRF->protectURI('plugins/Songza/settings/basic.html');
}

sub handler {

}

1;

__END__
