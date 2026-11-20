component hint="LDEV-6457: wsClient.getId() and scoped, newest-first websocketInfo()" {

	function onOpen( wsClient ) {
		arguments.wsClient.send( "id:" & arguments.wsClient.getId() );
	}

	function onMessage( wsClient, message ) {
		if ( arguments.message == "__WHOAMI__" ) {
			// what websocketInfo() returns from inside a listener: only this component's sessions, newest first
			var info = websocketInfo();
			var ids = [];
			var components = [];
			for ( var inst in info.instances ) {
				arrayAppend( ids, inst.id );
				if ( !arrayFind( components, inst.componentName ) )
					arrayAppend( components, inst.componentName );
			}
			return serializeJSON( {
				"getId": arguments.wsClient.getId(),
				"sessionId": arguments.wsClient.getSession().getId(),
				"instances": ids,
				"components": components,
				"allCount": arrayLen( websocketInfo( false, "*" ).instances )
			} );
		}
	}

	function onClose( wsClient, reasonPhrase ) {}

}
