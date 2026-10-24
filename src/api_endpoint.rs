// Copyright (c) 2026 Nguyễn Trọng Hà. All rights reserved.
// Project: BVĐKKH - Remote
// Author: Nguyễn Trọng Hà

use hbb_common::futures::{
    future::{BoxFuture, Shared},
    FutureExt,
};
use std::{
    sync::{
        atomic::{AtomicBool, Ordering},
        Mutex,
    },
    time::{Duration, Instant},
};

pub const INTERNAL: &str = "http://172.16.3.28:21114";
pub const PUBLIC: &str = "https://danhba.bvkhanhhoa.cloud";
const REFRESH_INTERVAL: Duration = Duration::from_secs(60);
const PROBE_TIMEOUT: Duration = Duration::from_secs(2);

static USE_PUBLIC: AtomicBool = AtomicBool::new(false);
type Probe = Shared<BoxFuture<'static, bool>>;
static PROBE: Mutex<Option<(Instant, Probe)>> = Mutex::new(None);

fn hospital_suffix(url: &str) -> Option<&str> {
    [INTERNAL, PUBLIC].iter().find_map(|origin| {
        url.strip_prefix(*origin).filter(|suffix| {
            suffix.is_empty() || suffix.starts_with('/') || suffix.starts_with('?')
        })
    })
}

fn selected_origin() -> &'static str {
    if USE_PUBLIC.load(Ordering::Relaxed) {
        PUBLIC
    } else {
        INTERNAL
    }
}

pub fn cached_server(configured: String) -> String {
    if configured == INTERNAL || configured == PUBLIC {
        selected_origin().to_owned()
    } else {
        configured
    }
}

pub fn invalidate(url: &str) {
    if hospital_suffix(url).is_some() {
        *PROBE.lock().unwrap() = None;
    }
}

async fn internal_available() -> bool {
    let client = match reqwest::Client::builder()
        .no_proxy()
        .timeout(PROBE_TIMEOUT)
        .redirect(reqwest::redirect::Policy::none())
        .build()
    {
        Ok(client) => client,
        Err(err) => {
            hbb_common::log::trace!("API health client failed: {err}");
            return false;
        }
    };
    let result = async {
        let response = client.get(format!("{INTERNAL}/healthz")).send().await?;
        let ok = response.status() == reqwest::StatusCode::OK;
        Ok::<_, reqwest::Error>(ok && response.text().await?.trim() == "ok")
    }
    .await;
    match result {
        Ok(available) => available,
        Err(err) => {
            hbb_common::log::trace!("Internal API health check failed: {err}");
            false
        }
    }
}

pub async fn resolve_url(url: String) -> String {
    let Some(suffix) = hospital_suffix(&url) else {
        return url;
    };
    let probe = {
        let mut cached = PROBE.lock().unwrap();
        if cached
            .as_ref()
            .map_or(true, |(at, _)| at.elapsed() >= REFRESH_INTERVAL)
        {
            *cached = Some((Instant::now(), internal_available().boxed().shared()));
        }
        match cached.as_ref() {
            Some((_, probe)) => probe.clone(),
            None => return url,
        }
    };
    let internal = probe.await;
    USE_PUBLIC.store(!internal, Ordering::Relaxed);
    format!("{}{suffix}", if internal { INTERNAL } else { PUBLIC })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn recognizes_only_hospital_api_origins_and_preserves_path_and_query() {
        assert_eq!(
            hospital_suffix(&format!("{INTERNAL}/api/heartbeat?q=1")),
            Some("/api/heartbeat?q=1")
        );
        assert_eq!(
            hospital_suffix(&format!("{PUBLIC}/admin/login")),
            Some("/admin/login")
        );
        assert_eq!(
            hospital_suffix("https://danhba.bvkhanhhoa.cloud.evil.test/api"),
            None
        );
        assert_eq!(hospital_suffix("http://172.16.3.28:211140/api"), None);
        assert_eq!(hospital_suffix("https://custom.example/api"), None);
    }
}
