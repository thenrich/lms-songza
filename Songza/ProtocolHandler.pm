package Plugins::Songza::ProtocolHandler;

# $Id$

use strict;
use base qw(Slim::Player::Protocols::HTTP);

use JSON::XS::VersionOneAndTwo;
use URI::Escape qw(uri_escape_utf8);
use Scalar::Util qw(blessed);
use Data::Dumper;
use Slim::Utils::Log;
use Slim::Utils::Misc;
use Slim::Utils::Prefs;

my $prefs = preferences('server');
my $log   = logger('plugin.songza');

sub isRemote { 1 }

sub getFormatForURL { 'mp3' }

# default buffer 3 seconds of 320k audio
sub bufferThreshold { 40 * ( $prefs->get('bufferSecs') || 3 ) }

sub canSeek { 0 }

sub canSeekError { return ( 'SEEK_ERROR_TYPE_NOT_SUPPORTED', 'songza' ); }

# To support remote streaming (synced players), we need to subclass Protocols::HTTP
sub new {
	my $class  = shift;
	my $args   = shift;

	my $client = $args->{client};
	
	my $song      = $args->{song};
	my $streamUrl = $song->streamUrl() || return;
	
	main::DEBUGLOG && $log->debug( 'Remote streaming songza track: ' . $streamUrl );

	my $sock = $class->SUPER::new( {
		url     => $streamUrl,
		song    => $args->{song},
		client  => $client,
		bitrate => 320_000,
	} ) || return;
	
	${*$sock}{contentType} = 'audio/mpeg';

	return $sock;
}

# Avoid scanning
sub scanUrl {
	my ( $class, $url, $args ) = @_;
	
	$args->{cb}->( $args->{song}->currentTrack() );
}

# Source for AudioScrobbler
sub audioScrobblerSource {
	my ( $class, $client, $url ) = @_;

	if ( $url =~ /\.dzr$/ ) {
		# R = Non-personalised broadcast
		return 'R';
	}

	# P = Chosen by the user
	return 'P';
}

# parseHeaders is used for proxied streaming
sub parseHeaders {
	my ( $self, @headers ) = @_;
	
	__PACKAGE__->parseDirectHeaders( $self->client, $self->url, @headers );
	
	return $self->SUPER::parseHeaders( @headers );
}

#sub parseDirectHeaders {
#	my ( $class, $client, $url, @headers ) = @_;
#	
#	my $length;
#	
#	# Clear previous duration, since we're using the same URL for all tracks
#	if ( $url =~ /\.dzr$/ ) {
#		Slim::Music::Info::setDuration( $url, 0 );
#	}
#	
#	my $bitrate = 320_000;
#
#	$client->streamingSong->bitrate($bitrate);
#
#	# ($title, $bitrate, $metaint, $redir, $contentType, $length, $body)
#	return (undef, $bitrate, 0, '', 'mp3', $length, undef);
#}

# Don't allow looping
sub shouldLoop { 0 }

sub isRepeatingStream {
	my ( undef, $song ) = @_;
	
	return $song->track()->url;
}

# Check if player is allowed to skip, using canSkip value from SN
sub canSkip {
	my $client = shift;
	
	if ( my $info = $client->playingSong->pluginData('info') ) {
		return $info->{canSkip};
	}
	
	return 1;
}

# Disallow skips in radio mode.
# Disallow smart radio after the limit is reached
#sub canDoAction {
#	my ( $class, $client, $url, $action ) = @_;
#	
#	
#	if ( $action eq 'stop' && !canSkip($client) ) {
#		# Is skip allowed?
#		
#		# Radio tracks do not allow skipping at all
#		if ( $url =~ m{^songza://\d+\.dzr$} ) {
#			return 0;
#		}
#		
#		# Smart Radio tracks have a skip limit
#		main::DEBUGLOG && $log->debug("Deezer: Skip limit exceeded, disallowing skip");
#		
#		my $line1 = $client->string('PLUGIN_SONGZA_ERROR');
#		my $line2 = $client->string('PLUGIN_SONGZA_SKIPS_EXCEEDED');
#		
#		$client->showBriefly( {
#			line1 => $line1,
#			line2 => $line2,
#			jive  => {
#				type => 'popupplay',
#				text => [ $line1, $line2 ],
#			},
#		},
#		{
#			block  => 1,
#			scroll => 1,
#		} );
#				
#		return 0;
#	}
#	
#	return 1;
#}

sub handleDirectError {
	my ( $class, $client, $url, $response, $status_line ) = @_;
	
	main::DEBUGLOG && $log->debug("Direct stream failed: [$response] $status_line\n");
	
	$client->controller()->playerStreamingFailed($client, 'PLUGIN_SONGZA_STREAM_FAILED');
}

sub _handleClientError {
	my ( $error, $client, $params ) = @_;
	
	my $song = $params->{song};
	$log->error(Dumper($error));
	#return if $song->pluginData('abandonSong');
	
	# Tell other clients to give up
	#$song->pluginData( abandonSong => 1 );
	
	#$params->{errorCb}->($error);
}

sub getNextTrack {
	$log->error("getNextTrack");
	my ( $class, $song, $successCb, $errorCb ) = @_;
	
	my $client = $song->master();
	my $url    = $song->track()->url;
	
	$song->pluginData( radioTrackURL => undef );
	$song->pluginData( radioTitle    => undef );
	$song->pluginData( radioTrack    => undef );
	$song->pluginData( abandonSong   => 0 );
	
	my $params = {
		song      => $song,
		url       => $url,
		successCb => $successCb,
		errorCb   => $errorCb,
	};
	
	# 1. If this is a radio-station then get next track info
	if ( $class->isRepeatingStream($song) ) {
		$log->error("-------------GET NEXT RADIO TRACK");
		_getNextRadioTrack($params);
	}
	else {
		_getTrack($params);
	}
}

sub _getNextRadioTrack {
		$log->error("getNextTrackradiotrack");

	my $params = shift;
		
	my $url = 'http://songza.com/api/1/station/1744350/next?format=mp3';

    Slim::Networking::SimpleAsyncHTTP->new(
        sub {
        	my $http = shift;
        	_gotNextRadioTrack($http, $params);
        },
        \&_gotNextRadioTrackError,
        
	)->get($url);

}

sub _gotNextRadioTrack {
		$log->error("-----------------GOT NEXT RADIO TRACK");

	my ($http, $sentParams) = @_;
	
	my $client = $http->params->{client};
	my $params = $http->params->{params};
	my $song = $sentParams->{song};
	
	my $track = eval { from_json( $http->content ) };
	
	if ( main::DEBUGLOG && $log->is_debug ) {
		$log->debug( 'Got next radio track: ' . Data::Dump::dump($track) );
	}
	
	
	# set metadata for track, will be set on playlist newsong callback
	my $url      = $track->{listen_url};
	my $title = $track->{song}{title} . ' ' . 
		'BY' . ' ' . $track->{song}{artist}{name} . ' ' . 
		'FROM' . ' ' . $track->{song}{album};
	
	$song->pluginData( radioTrackURL => $url );
	$song->pluginData( radioTitle    => $title );
	$song->pluginData( radioTrack    => $track );
	
	# We already have the metadata for this track, so can save calling getTrack
	my $icon = Plugins::Songza::Plugin->_pluginDataFor('icon');
	my $meta = {
		artist    => $track->{artist_name},
		album     => $track->{album_name},
		title     => $track->{title},
		duration  => $track->{duration} || 200,
		cover     => $track->{cover} || $icon,
		icon      => $icon,
		buttons   => {
			fwd => $track->{canSkip} ? 1 : 0,
			rew => 0,
		},
	};
	
	$song->duration( $meta->{duration} );
	
	my $cache = Slim::Utils::Cache->new;
	$cache->set( 'songza_meta_' . $track->{id}, $meta, 86400 );
	
	$sentParams->{url} = $url;
	$track->{url} = $track->{listen_url};
	$log->error("----------------URL");
	$log->error($sentParams->{url});
	
	_gotTrack( $client, $track, $sentParams );
}

sub _gotNextRadioTrackError {
		$log->error("GNRTE");

	my $http   = shift;
	my $client = $http->params('client');
	
	_handleClientError( $http->error, $client, $http->params->{params} );
}

sub _getTrack {
		$log->error("gettrack");

	my $params = shift;
	
	my $song   = $params->{song};
	my $client = $song->master();
	
	return if $song->pluginData('abandonSong');
	
	# Get track URL for the next track
	my ($trackId) = $params->{url} =~ m{songza://(.+)\.mp3};
	
	my $http = Slim::Networking::SqueezeNetwork->new(
		sub {
			my $http = shift;
			my $info = eval { from_json( $http->content ) };
			if ( $@ || $info->{error} ) {
				if ( main::DEBUGLOG && $log->is_debug ) {
					$log->debug( 'getTrack failed: ' . ( $@ || $info->{error} ) );
				}
				
				_gotTrackError( $@ || $info->{error}, $client, $params );
			}
			else {
				if ( main::DEBUGLOG && $log->is_debug ) {
					$log->debug( 'getTrack ok: ' . Data::Dump::dump($info) );
				}
				
				_gotTrack( $client, $info, $params );
			}
		},
		sub {
			my $http  = shift;
			
			if ( main::DEBUGLOG && $log->is_debug ) {
				$log->debug( 'getTrack failed: ' . $http->error );
			}
			
			_gotTrackError( $http->error, $client, $params );
		},
		{
			client => $client,
		},
	);
	
	main::DEBUGLOG && $log->is_debug && $log->debug('Getting next track playback info from SN');
	
	$http->get(
		Slim::Networking::SqueezeNetwork->url(
			'/api/songza/v1/playback/getMediaURL?trackId=' . uri_escape_utf8($trackId)
		)
	);
}

sub _gotTrack {
		$log->error("got track");

	my ( $client, $info, $params ) = @_;
	
    my $song = $params->{song};
    
	
	if (!$info->{url}) {
		_gotTrackError('No stream URL found', $client, $params);
		return;
	}
	
	# Save the media URL for use in strm
	$song->streamUrl($info->{url});

	# Save all the info
	$song->pluginData( info => $info );
	
	# Cache the rest of the track's metadata
	my $icon = Plugins::Songza::Plugin->_pluginDataFor('icon');
	my $meta = {
		artist    => $info->{artist_name},
		album     => $info->{album_name},
		title     => $info->{title},
		cover     => $info->{cover} || $icon,
		duration  => $info->{duration} || 200,
		info_link => 'plugins/songza/trackinfo.html',
		icon      => $icon,
	};
	
	$song->duration( $meta->{duration} );
	
	my $cache = Slim::Utils::Cache->new;
	$cache->set( 'songza_meta_' . $info->{id}, $meta, 86400 );
	
	# Async resolve the hostname so gethostbyname in Player::Squeezebox::stream doesn't block
	# When done, callback will continue on to playback
	my $dns = Slim::Networking::Async->new;
	$dns->open( {
		Host        => URI->new( $info->{url} )->host,
		Timeout     => 3, # Default timeout of 10 is too long, 
		                  # by the time it fails player will underrun and stop
		onDNS       => $params->{successCb},
		onError     => $params->{successCb}, # even if it errors, keep going
		passthrough => [],
	} );
	
	# Watch for playlist commands
	#Slim::Control::Request::subscribe( 
	#	\&_playlistCallback, 
	#	[['playlist'], ['newsong']],
	#	$song->master(),
	#);
}

sub _gotTrackError {
		$log->error("gottrackerror");

	my ( $error, $client, $params ) = @_;
	
	main::DEBUGLOG && $log->debug("Error during getTrackInfo: $error");

	$log->error("GOT TRACK ERROR");
	_handleClientError( $error, $client, $params );
}

sub _playlistCallback {
		$log->error("playlist callback");

	my $request = shift;
	my $client  = $request->client();
	my $p1      = $request->getRequest(1);
	
	return unless defined $client;
	
	# check that user is still using Deezer Radio
	my $song = $client->playingSong();
	
	if ( !$song || $song->currentTrackHandler ne __PACKAGE__ ) {
		# User stopped playing Deezer 

		main::DEBUGLOG && $log->debug( "Stopped Deezer, unsubscribing from playlistCallback" );
		Slim::Control::Request::unsubscribe( \&_playlistCallback, $client );
		
		return;
	}
	
	if ( $song->pluginData('radioTrackURL') && $p1 eq 'newsong' ) {
		# A new song has started playing.  We use this to change titles
		
		my $title = $song->pluginData('radioTitle');
		
		main::DEBUGLOG && $log->debug("Setting title for radio station to $title");
		
		Slim::Music::Info::setCurrentTitle( $song->track()->url, $title );
	}
}

sub canDirectStreamSong {
		$log->error("can direct stream song");

	my ( $class, $client, $song ) = @_;
	
	# We need to check with the base class (HTTP) to see if we
	# are synced or if the user has set mp3StreamingMethod
	return $class->SUPER::canDirectStream( $client, $song->streamUrl(), $class->getFormatForURL() );
}

# URL used for CLI trackinfo queries
sub trackInfoURL {
		$log->error("trackifno");

	my ( $class, $client, $url ) = @_;
	
	my $stationId;
	
	if ( $url =~ m{songza://(.+)\.dzr} ) {
		$stationId = $1;
		my $song = $client->currentSongForUrl($url);
		
		# Radio mode, pull track ID from lastURL
		if ( $song ) {
			$url = $song->pluginData('radioTrackURL');
		}
	}

	my ($trackId) = $url =~ m{songza://(.+)\.mp3};
	
	# SN URL to fetch track info menu
	my $trackInfoURL = Slim::Networking::SqueezeNetwork->url(
		'/api/songza/v1/opml/trackinfo?trackId=' . $trackId
	);
	
	if ( $stationId ) {
		$trackInfoURL .= '&stationId=' . $stationId;
	}
	
	return $trackInfoURL;
}

# Track Info menu
sub trackInfo {
		$log->error("trackinfo");

	my ( $class, $client, $track ) = @_;
	
	my $url          = $track->url;
	my $trackInfoURL = $class->trackInfoURL( $client, $url );
	
	# let XMLBrowser handle all our display
	my %params = (
		header   => 'PLUGIN_SONGZA_GETTING_TRACK_DETAILS',
		modeName => 'Deezer Now Playing',
		title    => Slim::Music::Info::getCurrentTitle( $client, $url ),
		url      => $trackInfoURL,
	);
	
	main::DEBUGLOG && $log->debug( "Getting track information for $url" );

	Slim::Buttons::Common::pushMode( $client, 'xmlbrowser', \%params );
	
	$client->modeParam( 'handledTransition', 1 );
}

# Metadata for a URL, used by CLI/JSON clients
sub getMetadataFor {
	$log->error("get mketa");
	my ( $class, $client, $url ) = @_;
	$log->error($url);
	$url =~ s/songza:\/\//http:\/\//;
	
   my $song = $client->currentSongForUrl($url);
    if (!$song || !($url = $song->pluginData('radioTrackURL'))) {
            return {
                    type      => 'AAC (songza)',
            };
    }
	
}



1;
