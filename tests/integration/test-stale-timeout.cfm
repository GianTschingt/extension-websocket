<cfscript>
// LDEV-6457 - sessions that send nothing within staleTimeout are closed (e.g. a page frozen in
// Chrome's back/forward cache), sessions that keep sending stay open
writeOutput( "=== LDEV-6457: staleTimeout closes silent sessions ===" & chr( 10 ) );

try {
	if ( !structKeyExists( getFunctionList(), "CreateWebSocketClient" ) )
		throw( message="CreateWebSocketClient not available", type="TestSetupError" );

	silent = new tests.integration.ClientListener();
	active = new tests.integration.ClientListener();
	wsSilent = CreateWebSocketClient( "ws://localhost:8888/ws/StaleListener?who=silent", silent );
	wsActive = CreateWebSocketClient( "ws://localhost:8888/ws/StaleListener?who=active", active );
	sleep( 300 );

	// StaleListener has staleTimeout=2, keep one client talking for ~5 seconds
	for ( i = 1; i <= 10; i++ ) {
		wsActive.sendText( "hb" );
		sleep( 500 );
	}

	remaining = [];
	for ( inst in websocketInfo( false, "StaleListener" ).instances )
		arrayAppend( remaining, inst.session.queryString );
	writeOutput( "open StaleListener sessions: " & remaining.toJSON() & chr( 10 ) );

	errors = [];
	if ( arrayFind( remaining, "who=silent" ) )
		arrayAppend( errors, "silent session was not closed after staleTimeout" );
	if ( !arrayFind( remaining, "who=active" ) )
		arrayAppend( errors, "active session was closed although it kept sending" );

	try { wsActive.disconnect(); } catch ( any e ) {}
	try { wsSilent.disconnect(); } catch ( any e ) {}

	if ( arrayLen( errors ) ) {
		writeOutput( chr( 10 ) & "FAILED:" & chr( 10 ) );
		for ( err in errors )
			writeOutput( "  - #err#" & chr( 10 ) );
		cfheader( statuscode=500, statustext="Test Failed" );
	}
	else {
		writeOutput( chr( 10 ) & "SUCCESS: staleTimeout closed the silent session and kept the active one" & chr( 10 ) );
	}
}
catch ( any e ) {
	writeOutput( "FAILED with exception:" & chr( 10 ) );
	writeOutput( e.message & chr( 10 ) & e.stacktrace );
	cfheader( statuscode=500, statustext="Test Failed" );
}
</cfscript>
