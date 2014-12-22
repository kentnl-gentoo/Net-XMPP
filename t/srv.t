
use lib 't/lib';

use strict;
use warnings;

use Test::More tests => '7';
use Net::XMPP::Test::Utils qw/
	can_run_tests
	get_conn_params
	get_auth_params
	bare_jid
/;
use Try::Tiny;

BEGIN { use_ok('Net::XMPP'); }

SKIP: {
	skip "No accounts configured in $Net::XMPP::Test::Utils::accounts_file", 6
		unless can_run_tests();

	my $test_account = 'srv_and_tls';

	my $conn_params = get_conn_params( $test_account );
	my $auth_params = get_auth_params( $test_account );
	my $my_full_jid = bare_jid( $test_account ) . '/' . $auth_params->{'resource'};

	my $client = Net::XMPP::Client->new(
		debuglevel => 2,
		debug      => 'stderr',
	);

	isa_ok( $client, 'Net::XMPP::Client');

	$client->SetCallBacks(
		onconnect => \&onConnect,
		onauth    => \&onAuth,
		message   => \&onMessage,
	);

	try {
		$client->Execute( %{$auth_params}, %{$conn_params} );
	}
	catch {
		warn "caught error: $_"; # not $@
	};

	sub onConnect {
		ok(1, 'Connected');
	}

	# After successful authentication, send a test message to our full JID
	sub onAuth {
		ok( 1, 'Authenticated');
		isa_ok( $client->PresenceSend(), 'Net::XMPP::Presence');

		$client->MessageSend(
			to      => $my_full_jid,
			subject => 'Test message',
			body    => 'This is a test.'
		);
		print STDERR ">>> In onAuth; sent message to $my_full_jid\n";
	}

	# Check that the contents match what we sent above
	sub onMessage {
		print STDERR ">>> In onMessage\n";
		my $sid = shift;
		my $message = shift;

		#return unless $my_full_jid
		#	eq $message->GetFrom('jid')->GetJID('full');

		is( $message->GetSubject(), 'Test message',    'Subject' );
		is( $message->GetBody(),    'This is a test.', 'Body'    );

		$client->Disconnect();

		exit(0);
	}
}
