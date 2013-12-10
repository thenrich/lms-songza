package Plugins::Songza::ProtocolHandler;

use strict;
use warnings;
use base qw(Slim::Player::Protocols::HTTP);

use Scalar::Util qw(blessed);
use Slim::Player::Playlist;
use Slim::Utils::Log;
use Slim::Utils::Misc;
use Slim::Utils::Prefs;

#use Plugins::GoogleMusic::Plugin;
#use Plugins::GoogleMusic::SongzaAPI;

my $log = logger('plugin.songza');
my $prefs = preferences('plugin.songza');

Slim::Player::ProtocolHandlers->registerHandler('songza', __PACKAGE__);

# To support remote streaming (synced players), we need to subclass Protocols::HTTP
sub new {
	my $class  = shift;
	my $args   = shift;

	my $client = $args->{client};
	
	my $song      = $args->{song};
	my $streamUrl = $song->streamUrl() || return;
	my $track     = $song->pluginData('info') || {};
	
	main::DEBUGLOG && $log->debug( 'start streaming: ' . $streamUrl );

	my $sock = $class->SUPER::new( {
		url     => $streamUrl,
		song    => $song,
		client  => $client,
	} ) || return;
	
	${*$sock}{contentType} = 'audio/mpeg';

	return $sock;
}

# Always MP3
sub getFormatForURL {
	return 'mp3';
}

# Source for AudioScrobbler
sub audioScrobblerSource {
	# P = Chosen by the user
	return 'P';
}


1;

__END__
