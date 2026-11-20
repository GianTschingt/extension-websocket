<cfscript>
// LDEV-6457 - a listener must be able to identify the sending connection without scanning websocketInfo()
//   1. wsClient.getId() returns the connection's own id (same as getSession().getId())
//   2. websocketInfo() called inside a listener only returns that listener's sessions
//   3. instances are ordered newest first
writeOutput( "=== LDEV-6457: getId() + scoped, newest-first websocketInfo() ===" & chr( 10 ) );

try {
	if ( !structKeyExists( getFunctionList(), "CreateWebSocketClient" ) )
		throw( message="CreateWebSocketClient not available", type="TestSetupError" );

	// a connection to another listener, must not show up in IdentityListener's websocketInfo()
	other = new tests.integration.ClientListener();
	wsOther = CreateWebSocketClient( "ws://localhost:8888/ws/SessionAccessListener?token=other", other );
	sleep( 300 );

	clients = [];
	sockets = [];
	for ( i = 1; i <= 3; i++ ) {
		c = new tests.integration.ClientListener();
		arrayAppend( clients, c );
		arrayAppend( sockets, CreateWebSocketClient( "ws://localhost:8888/ws/IdentityListener?n=#i#", c ) );
		sleep( 300 );
	}

	// the oldest connection asks, like a heartbeat from a page that is still around
	sockets[ 1 ].sendText( "__WHOAMI__" );
	sleep( 500 );

	errors = [];
	openIds = [];
	for ( c in clients ) {
		id = "";
		for ( m in c.getMessages() )
			if ( left( m, 3 ) == "id:" )
				id = mid( m, 4, len( m ) );
		arrayAppend( openIds, id );
	}
	writeOutput( "ids in open order: " & openIds.toJSON() & chr( 10 ) );

	reply = {};
	for ( m in clients[ 1 ].getMessages() )
		if ( isJSON( m ) )
			reply = deserializeJSON( m );
	writeOutput( "reply: " & serializeJSON( reply ) & chr( 10 ) );

	if ( structIsEmpty( reply ) ) {
		arrayAppend( errors, "no __WHOAMI__ reply" );
	}
	else {
		if ( reply.getId != openIds[ 1 ] )
			arrayAppend( errors, "getId() [#reply.getId#] is not the id the connection got in onOpen [#openIds[ 1 ]#]" );
		if ( reply.getId != reply.sessionId )
			arrayAppend( errors, "getId() [#reply.getId#] differs from getSession().getId() [#reply.sessionId#]" );

		expected = duplicate( openIds );
		expected = expected.reverse();
		if ( reply.instances.toJSON() != expected.toJSON() )
			arrayAppend( errors, "websocketInfo() inside the listener should list only IdentityListener sessions newest first, expected #expected.toJSON()# got #reply.instances.toJSON()#" );
		if ( reply.components.toJSON() != [ "IdentityListener" ].toJSON() )
			arrayAppend( errors, "websocketInfo() inside the listener returned other components: #reply.components.toJSON()#" );
		if ( reply.allCount < 4 )
			arrayAppend( errors, "websocketInfo( false, '*' ) should include the other listener too, got #reply.allCount# instances" );
	}

	// outside a listener, websocketInfo() returns all sessions of this web context, newest first
	outside = websocketInfo().instances;
	seqOk = true;
	for ( i = 2; i <= arrayLen( outside ); i++ )
		if ( dateCompare( outside[ i - 1 ].openTime, outside[ i ].openTime ) < 0 )
			seqOk = false;
	if ( !seqOk )
		arrayAppend( errors, "websocketInfo() outside a listener is not ordered newest first" );
	if ( arrayLen( websocketInfo( false, "IdentityListener" ).instances ) != 3 )
		arrayAppend( errors, "websocketInfo( false, 'IdentityListener' ) should return 3 instances" );

	for ( s in sockets )
		s.disconnect();
	wsOther.disconnect();
	sleep( 300 );

	if ( arrayLen( errors ) ) {
		writeOutput( chr( 10 ) & "FAILED:" & chr( 10 ) );
		for ( err in errors )
			writeOutput( "  - #err#" & chr( 10 ) );
		cfheader( statuscode=500, statustext="Test Failed" );
	}
	else {
		writeOutput( chr( 10 ) & "SUCCESS: getId() + scoped, newest-first websocketInfo() OK" & chr( 10 ) );
	}
}
catch ( any e ) {
	writeOutput( "FAILED with exception:" & chr( 10 ) );
	writeOutput( e.message & chr( 10 ) & e.stacktrace );
	cfheader( statuscode=500, statustext="Test Failed" );
}
</cfscript>
