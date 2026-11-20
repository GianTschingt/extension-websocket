component hint="LDEV-6457: close sessions that did not send a message within staleTimeout" {

	property name="staleTimeout" default=2;
	property name="pingInterval" default=0;

	function onOpen( wsClient ) {
		arguments.wsClient.send( "CONNECTED" );
	}

	function onMessage( wsClient, message ) {}

	function onClose( wsClient, reasonPhrase ) {}

}
