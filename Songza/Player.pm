package Plugins::Songza::Player;

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


sub go {
    
}
