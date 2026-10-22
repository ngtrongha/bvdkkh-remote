// Copyright (c) 2026 Nguyễn Trọng Hà. All rights reserved.
// Project: BVĐKKH - Remote
// Author: Nguyễn Trọng Hà

use crate::{common::display_version_from_release_id, update_metadata::UpdateArtifactQuery};
use serde_json::Value;

pub(super) fn artifact_filename(
    version: &str,
    query: &UpdateArtifactQuery<'_>,
    legacy_windows: bool,
    sciter: bool,
) -> String {
    if query.platform == "windows" {
        if sciter {
            return format!("rustdesk-{version}-{}-sciter.exe", query.arch);
        }
        if legacy_windows {
            return format!("rustdesk-{version}-win7-{}.{}", query.arch, query.format);
        }
    }
    format!("rustdesk-{version}-{}.{}", query.arch, query.format)
}

pub(super) fn asset_details<'a>(release: &'a Value, filename: &str) -> Option<(u64, &'a str)> {
    let asset = release.get("assets")?.as_array()?.iter().find(|asset| {
        asset.get("name").and_then(Value::as_str) == Some(filename)
            && asset.get("state").and_then(Value::as_str) == Some("uploaded")
    })?;
    let size = asset.get("size")?.as_u64()?;
    let digest = asset.get("digest")?.as_str()?.strip_prefix("sha256:")?;
    (size > 0 && digest.len() == 64 && digest.bytes().all(|b| b.is_ascii_hexdigit()))
        .then_some((size, digest))
}

pub(super) fn latest_release<'a>(
    releases: &'a [Value],
    current_version: &str,
    query: &UpdateArtifactQuery<'_>,
    legacy_windows: bool,
    sciter: bool,
) -> Option<&'a Value> {
    let current = hbb_common::get_version_number(current_version);
    releases.iter().filter_map(|release| {
        if release.get("draft").and_then(Value::as_bool) != Some(false)
            || release.get("prerelease").and_then(Value::as_bool) != Some(false)
        {
            return None;
        }
        let tag = release.get("tag_name")?.as_str()?;
        let version = display_version_from_release_id(tag).ok()?;
        let number = hbb_common::get_version_number(&version);
        let expected_url = format!("https://github.com/ngtrongha/bvdkkh-remote-release/releases/tag/{tag}");
        if number <= current || release.get("html_url")?.as_str()? != expected_url {
            return None;
        }
        let filename = artifact_filename(&version, query, legacy_windows, sciter);
        asset_details(release, &filename)?;
        Some((number, release))
    }).max_by_key(|(number, _)| *number).map(|(_, release)| release)
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn filenames_keep_windows_channels_and_architectures_separate() {
        let query = UpdateArtifactQuery { platform: "windows", arch: "x86_64", format: "exe" };
        assert_eq!(artifact_filename("1.5.18", &query, true, false), "rustdesk-1.5.18-win7-x86_64.exe");
        assert_eq!(artifact_filename("1.5.18", &query, false, false), "rustdesk-1.5.18-x86_64.exe");
        assert_eq!(artifact_filename("1.5.18", &query, true, true), "rustdesk-1.5.18-x86_64-sciter.exe");
    }

    #[test]
    fn chooses_newest_ready_stable_release_for_this_windows_channel() {
        let make = |tag: &str, filename: &str| json!({
            "tag_name": tag, "html_url": format!("https://github.com/ngtrongha/bvdkkh-remote-release/releases/tag/{tag}"),
            "draft": false, "prerelease": false,
            "assets": [{"name": filename, "size": 100, "state": "uploaded", "digest": format!("sha256:{}", "a".repeat(64))}]
        });
        let mut prerelease = make("v1.5.21", "rustdesk-1.5.21-win7-x86_64.exe");
        prerelease["prerelease"] = json!(true);
        let mut no_hash = make("v1.5.22", "rustdesk-1.5.22-win7-x86_64.exe");
        no_hash["assets"][0]["digest"] = Value::Null;
        let releases = vec![make("v1.5.20", "rustdesk-1.5.20-x86_64.exe"),
            make("v1.5.18", "rustdesk-1.5.18-win7-x86_64.exe"), prerelease, no_hash,
            make("v1.5.19", "rustdesk-1.5.19-win7-x86_64.exe")];
        let query = UpdateArtifactQuery { platform: "windows", arch: "x86_64", format: "exe" };
        assert_eq!(latest_release(&releases, "1.5.17", &query, true, false).unwrap()["tag_name"], "v1.5.19");
        assert!(latest_release(&releases, "1.5.23", &query, true, false).is_none());
    }
}
