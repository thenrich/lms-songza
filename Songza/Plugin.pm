package Plugins::Songza::Plugin;

# $Id$

use strict;
use base qw(Slim::Plugin::OPMLBased);

use URI::Escape qw(uri_escape_utf8);

use Plugins::Songza::ProtocolHandler;

my $log = Slim::Utils::Log->addLogCategory( {
	category     => 'plugin.songza',
	defaultLevel => 'ERROR',
	description  => 'PLUGIN_SONGZA_MODULE_NAME',
} );



sub initPlugin {
	my $class = shift;
	
	Slim::Player::ProtocolHandlers->registerHandler(
		songza => 'Plugins::Songza::ProtocolHandler'
	);

	$class->SUPER::initPlugin(
		feed   => \&topLevel,
		tag    => 'songza',
		menu   => 'radios',
		weight => 1,
		is_app => $class->can('nonSNApps') ? 1 : undef,
	);
	
	# Note: Deezer does not wish to be included in context menus
	# that is why a track info menu item is not created here
	
	if ( !main::SLIM_SERVICE ) {
		# Add a function to view trackinfo in the web
		Slim::Web::Pages->addPageFunction( 
			'plugins/songza/trackinfo.html',
			sub {
				my $client = $_[0];
				my $params = $_[1];
				
				my $url;
				
				my $id = $params->{sess} || $params->{item};
				
				if ( $id ) {
					# The user clicked on a different URL than is currently playing
					if ( my $track = Slim::Schema->find( Track => $id ) ) {
						$url = $track->url;
					}
					
					# Pass-through track ID as sess param
					$params->{sess} = $id;
				}
				else {
					$url = Slim::Player::Playlist::url($client);
				}
				
				Slim::Web::XMLBrowser->handleWebIndex( {
					client  => $client,
					feed    => Plugins::Songza::ProtocolHandler->trackInfoURL( $client, $url ),
					path    => 'plugins/songza/trackinfo.html',
					title   => 'Songza Track Info',
					timeout => 35,
					args    => \@_
				} );
			},
		);
	}
}

sub topLevel {
        my ($client, $callback, $args) = @_;

        

        my @menu = (
                { name  => 'Go', type => "audio", url => 'songza://songza.com/api/1/station/1744350/next?format=mp3'}
        );

        $callback->(\@menu);
}

sub playlistHandler {

}

sub getDisplayName {
	return 'PLUGIN_SONGZA';
}

# Don't add this item to any menu
sub playerMenu { }

1;
