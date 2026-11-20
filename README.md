# Lucee WebSocket Extension

[![Java CI](https://github.com/lucee/extension-websocket/actions/workflows/main.yml/badge.svg)](https://github.com/lucee/extension-websocket/actions/workflows/main.yml)

WebSocket server support for Lucee CFML — define listener components with lifecycle methods (`onOpen`, `onMessage`, `onClose`, etc) and Lucee handles the WebSocket endpoint for you.

**Requires Lucee 6.2+**. Dual API support — loads on both Lucee 6.x (Tomcat 9 / `javax.websocket`) and Lucee 7.x (Tomcat 11 / `jakarta.websocket`).

## Installation

Install via Lucee Admin, or pin in your environment:

```bash
LUCEE_EXTENSIONS=org.lucee:websocket-extension:3.1.0.0-SNAPSHOT
```

## Documentation

- **Docs**: [docs.lucee.org/recipes/websocket-extension.html](https://docs.lucee.org/recipes/websocket-extension.html)
- **Downloads**: [download.lucee.org](https://download.lucee.org/#3F9DFF32-B555-449D-B0EB5DB723044045)
- **Issues**: [Lucee JIRA — WebSocket Issues](https://luceeserver.atlassian.net/issues/?jql=labels%20%3D%20%22websockets%22)

### What's Included

- **Listener components** — CFML components with `onOpen`, `onMessage`, `onClose`, `onError`, `onFirstOpen`, `onLastClose` lifecycle methods.
- **Async open handler** — optional `onOpenAsync` runs in parallel with `onOpen` for long-running init work.
- **Connection identity** — `wsClient.getId()` returns the id of the connection a listener function was called for.
- **JSR-356 Session access** — `wsClient.getSession()` exposes the underlying `javax.websocket.Session` / `jakarta.websocket.Session` for per-connection state (`getUserProperties()`), connection identity (`getId()`), and handshake data (`getRequestParameterMap()`).
- **`websocketInfo()` BIF** — returns `version`, `mapping`, `config`, `configFile`, `log`, and an `instances[]` array of the open sessions of the current web context, newest first, with their `id`, `componentName`, `openTime`, `lastMessageTime`, component + session metadata. Called from inside a listener it only returns the sessions of that listener component (use `websocketInfo( false, "*" )` for all of them).
- **Stale session cleanup** — periodic ping/pong closes dead connections, an optional `staleTimeout` closes connections that stopped sending (e.g. a page frozen in the browser's back/forward cache).
- **Extension hot-upgrade** — upgrade the `.lex` in-place via `inject()` without restarting the servlet container.
- **Configurable timeouts** — `idleTimeout`, `requestTimeout`, `pingInterval`, `pongTimeout` and `staleTimeout` per web context via `websocket.json`, or per listener as component properties.

## Configuration

Listener components live in a directory configured in `{lucee-config}/websocket.json` (auto-created with defaults on first load):

```json
{
    "directory": "{lucee-config}/websockets/",
    "requestTimeout": 50,
    "idleTimeout": 300,
    "pingInterval": 30,
    "pongTimeout": 10,
    "staleTimeout": 0
}
```

All values are in seconds.

| Setting | Default | |
|---|---|---|
| `requestTimeout` | 50 | max execution time of a listener function |
| `idleTimeout` | 300 | the servlet container closes a session without any traffic for that long |
| `pingInterval` | 30 | send a ping to every session this often, `0` disables ping/pong |
| `pongTimeout` | 10 | close a session that did not answer a ping within this time (dead or half-open connection) |
| `staleTimeout` | 0 (off) | close a session that did not **send a message** for this long. Pongs do not count, browsers answer pings even for pages that are frozen in the back/forward cache. Only enable this for clients that send a regular heartbeat, and set it to a few heartbeat intervals. |

`idleTimeout`, `pingInterval`, `pongTimeout` and `staleTimeout` can also be set per listener component:

```cfml
component {
    property name="staleTimeout" default=10; // our page sends a heartbeat every 2 seconds
    ...
}
```

Override the config path with `-Dlucee.websocket.config=/path/to/websocket.json` or the `LUCEE_WEBSOCKET_CONFIG` env var.

## Quick Example

A listener component dropped in the configured directory as `EchoListener.cfc`:

```cfml
component {

    function onOpen( wsClient ) {
        wsClient.send( "CONNECTED" );
    }

    function onMessage( wsClient, message ) {
        wsClient.send( "ECHO:" & message );
    }

    function onClose( wsClient, reasonPhrase ) {}

    function onError( wsClient, cfCatch ) {
        systemOutput( "WS error: #cfCatch.message#", true );
    }

}
```

Clients connect to `ws://yourhost/ws/EchoListener`.

## Identifying the connection

Every listener function gets the `wsClient` of the connection it was called for. Use `wsClient.getId()` (or keep your own data in `variables`, each connection gets its own listener instance) to know who sent a message:

```cfml
component {

    function onOpen( wsClient ) {
        variables.userId = url.userId ?: 0; // query string of the websocket URL
    }

    function onMessage( wsClient, message ) {
        return serializeJSON( { socketID: arguments.wsClient.getId(), userId: variables.userId } );
    }

}
```

Don't identify the sender by looping over `websocketInfo().instances` and picking the first session that matches a user. A browser can have more than one open socket per user, for example when you navigate away from a page, Chrome may keep the previous page in its back/forward cache with its socket still open for a minute or more, so that loop easily picks the wrong socket. If your pages send a heartbeat, set `staleTimeout` so such sockets are closed quickly, or close the socket in the page on `pagehide`:

```javascript
window.addEventListener( "pagehide", () => socket.close( 1000 ) );
```

## Server state

```cfml
info = websocketInfo();
writeDump( info );
```

## Related

- **[extension-websocket-client](https://github.com/lucee/extension-websocket-client)** — WebSocket client BIFs (`CreateWebSocketClient`) for CFML. This repo's integration tests ([test-websocket-client.cfm](tests/test-websocket-client.cfm), [test-idle-timeout.cfm](tests/test-idle-timeout.cfm)) exercise the full client⇄server loop, so they cover both extensions.
- **[Lucee-websocket-commandbox](https://github.com/webonix/Lucee-websocket-commandbox)** — full client + server example with JavaScript and CFML.
- **[CFCAMP 2024 presentation](https://www.cfcamp.org/resource/getting-started-with-lucee-6-websockets.html)** — Getting Started with Lucee 6 WebSockets.
