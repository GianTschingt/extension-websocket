package org.lucee.extension.websocket.util;

import java.nio.ByteBuffer;

import org.lucee.extension.websocket.BaseWebSocketEndpoint;
import org.lucee.extension.websocket.BaseWebSocketEndpoint.Instance;

import lucee.runtime.config.ConfigWeb;

/**
 * Background thread that detects stale websocket sessions and closes them.
 * <ul>
 * <li><b>pingInterval / pongTimeout</b>: sends a ping frame every [pingInterval] and closes the
 * session when no pong arrives within [pongTimeout]. This detects dead or half-open connections
 * (client crashed, network gone, proxy dropped the connection).</li>
 * <li><b>staleTimeout</b>: closes the session when the client did not send any message within
 * [staleTimeout]. Pongs do not count, because browsers answer pings from their network stack even
 * while the page itself is frozen, for example in Chrome's back/forward cache. Use this for
 * clients that send a regular heartbeat.</li>
 * </ul>
 * The thread only runs while there are open sessions with ping or stale detection enabled.
 */
public final class SessionMonitor extends Thread {

	private static final long TICK = 1000;
	private static final Object lock = new Object();
	private static SessionMonitor thread;

	private SessionMonitor() {
		super("lucee-websocket-session-monitor");
		setDaemon(true);
	}

	public static void ensureRunning() {
		synchronized (lock) {
			if (thread == null) {
				thread = new SessionMonitor();
				thread.start();
			}
		}
	}

	@Override
	public void run() {
		while (true) {
			try {
				sleep(TICK);
			}
			catch (InterruptedException e) {
				synchronized (lock) {
					thread = null;
				}
				return;
			}
			synchronized (lock) {
				if (BaseWebSocketEndpoint.instances.isEmpty()) {
					thread = null;
					return;
				}
			}
			for (Instance inst: BaseWebSocketEndpoint.instances.values()) {
				try {
					check(inst, System.currentTimeMillis());
				}
				catch (Exception e) {
					ConfigWeb cw = inst.endpoint == null ? null : inst.endpoint.getConfig();
					if (cw != null) WSUtil.warn(cw, "stale session check failed: " + e.getMessage());
				}
			}
		}
	}

	static void check(Instance inst, long now) throws Exception {
		BaseWebSocketEndpoint ep = inst.endpoint;
		if (ep == null) return;
		ConfigWeb cw = ep.getConfig();
		if (cw == null || !WSUtil.isOpen(cw, inst.session)) return;

		// no message from the client within staleTimeout (pongs do not count)
		long stale = ep.getStaleTimeout();
		if (stale > 0 && now - inst.lastMessage >= stale) {
			String msg = "no message received within staleTimeout [" + (stale / 1000) + "s]";
			WSUtil.info(cw, "closing stale session [" + WSUtil.getId(cw, inst.session) + "] of component [" + inst.componentName + "]: " + msg);
			WSUtil.closeGoingAway(cw, inst.session, msg);
			return;
		}

		long ping = ep.getPingInterval();
		if (ping <= 0) return;
		long pong = ep.getPongTimeout();
		boolean outstanding = inst.lastPing > 0 && inst.lastPong < inst.lastPing;

		// ping sent, but no pong within pongTimeout
		if (outstanding && pong > 0 && now - inst.lastPing >= pong) {
			String msg = "no pong received within pongTimeout [" + (pong / 1000) + "s]";
			WSUtil.info(cw, "closing stale session [" + WSUtil.getId(cw, inst.session) + "] of component [" + inst.componentName + "]: " + msg);
			WSUtil.closeGoingAway(cw, inst.session, msg);
			return;
		}

		// time for the next ping
		if (!outstanding && now - Math.max(inst.lastPing, inst.openTime) >= ping) {
			inst.lastPing = now;
			WSUtil.sendPing(cw, inst.session, ByteBuffer.allocate(0));
		}
	}
}
