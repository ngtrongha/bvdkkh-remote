// Copyright (c) 2026 Nguyễn Trọng Hà. All rights reserved.
// Project: BVĐKKH - Remote
// Author: Nguyễn Trọng Hà

use base::config::keys;
use hbb_common::config::{self, Config};

const INTERNAL_HOST: &str = "172.16.3.28";
const PUBLIC_HOST: &str = "danhba.bvkhanhhoa.cloud";

fn hospital_host(host: &str) -> bool {
    matches!(
        host,
        "172.16.3.28"
            | "172.16.3.28:21116"
            | "172.16.3.28:21117"
            | "172.16.3.28:21118"
            | "172.16.3.28:21119"
            | "danhba.bvkhanhhoa.cloud"
            | "danhba.bvkhanhhoa.cloud:21116"
            | "danhba.bvkhanhhoa.cloud:21117"
            | "danhba.bvkhanhhoa.cloud:21118"
            | "danhba.bvkhanhhoa.cloud:21119"
    )
}

fn managed(server: &str, relay: &str, api: &str) -> bool {
    hospital_host(server)
        && (relay.is_empty() || hospital_host(relay))
        && matches!(
            api,
            crate::api_endpoint::INTERNAL | crate::api_endpoint::PUBLIC
        )
}

fn route(internal: bool) -> (&'static str, &'static str, &'static str) {
    if internal {
        (INTERNAL_HOST, crate::api_endpoint::INTERNAL, "N")
    } else {
        (PUBLIC_HOST, crate::api_endpoint::PUBLIC, "Y")
    }
}

fn relay_for_route(provided: String, selected: &str) -> String {
    if hospital_host(&provided) && hospital_host(selected) {
        selected.to_owned()
    } else {
        provided
    }
}

pub fn relay_server(provided: String) -> String {
    let relay = Config::get_option(keys::OPTION_RELAY_SERVER);
    if managed(
        &Config::get_rendezvous_server(),
        &relay,
        &Config::get_option(keys::OPTION_API_SERVER),
    ) {
        relay_for_route(provided, &relay)
    } else {
        provided
    }
}

// shortcut: WS mode is process-wide; revisit for simultaneous hospital/foreign-server sessions.
pub async fn select_server() -> Option<String> {
    if !managed(
        &Config::get_rendezvous_server(),
        &Config::get_option(keys::OPTION_RELAY_SERVER),
        &Config::get_option(keys::OPTION_API_SERVER),
    ) {
        return None;
    }
    let api = crate::api_endpoint::resolve_url(crate::api_endpoint::INTERNAL.to_owned()).await;
    let (host, api, websocket) = route(api == crate::api_endpoint::INTERNAL);
    let options = [
        (keys::OPTION_CUSTOM_RENDEZVOUS_SERVER, host),
        (keys::OPTION_RELAY_SERVER, host),
        (keys::OPTION_API_SERVER, api),
        (keys::OPTION_ALLOW_WEBSOCKET, websocket),
    ];
    let changed = {
        let mut settings = config::OVERWRITE_SETTINGS.write().unwrap();
        let changed = options
            .iter()
            .any(|(key, value)| settings.get(*key).map(String::as_str) != Some(*value));
        if changed {
            for (key, value) in options {
                settings.insert(key.to_owned(), value.to_owned());
            }
        }
        changed
    };
    if changed {
        {
            let mut local = config::OVERWRITE_LOCAL_SETTINGS.write().unwrap();
            for (key, value) in options {
                local.insert(key.to_owned(), value.to_owned());
            }
        }
        {
            let mut exe = config::EXE_RENDEZVOUS_SERVER.write().unwrap();
            if !exe.is_empty() && hospital_host(&exe) {
                *exe = host.to_owned();
            }
        }
        // Re-register on the new transport without closing established sessions.
        #[cfg(not(target_os = "ios"))]
        crate::RendezvousMediator::restart();
    }
    Some(Config::get_rendezvous_server())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn public_route_uses_the_public_host_https_and_websocket_together() {
        assert_eq!(route(false), ("danhba.bvkhanhhoa.cloud", "https://danhba.bvkhanhhoa.cloud", "Y"));
        assert_eq!(route(true), ("172.16.3.28", "http://172.16.3.28:21114", "N"));
    }

    #[test]
    fn custom_server_relay_and_api_keep_their_existing_configuration() {
        assert!(managed("172.16.3.28:21116", "172.16.3.28", crate::api_endpoint::INTERNAL));
        assert!(managed("danhba.bvkhanhhoa.cloud:21116", "danhba.bvkhanhhoa.cloud", crate::api_endpoint::PUBLIC));
        assert!(!managed("custom.example:21116", INTERNAL_HOST, crate::api_endpoint::INTERNAL));
        assert!(!managed("172.16.3.28:21116", "custom.example", crate::api_endpoint::INTERNAL));
        assert!(!managed("172.16.3.28:21116", INTERNAL_HOST, "https://custom.example"));
    }

    #[test]
    fn lan_and_public_peers_use_the_relay_route_reachable_on_their_network() {
        assert_eq!(relay_for_route("172.16.3.28:21117".to_owned(), PUBLIC_HOST), PUBLIC_HOST);
        assert_eq!(relay_for_route("172.16.3.28:21119".to_owned(), PUBLIC_HOST), PUBLIC_HOST);
        assert_eq!(relay_for_route(PUBLIC_HOST.to_owned(), INTERNAL_HOST), INTERNAL_HOST);
        assert_eq!(relay_for_route("custom.example:21117".to_owned(), PUBLIC_HOST), "custom.example:21117");
    }
}
