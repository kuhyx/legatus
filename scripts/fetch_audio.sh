#!/bin/bash

# ============================================================================
# Fetch the CC0 sound samples listed in assets/audio/sources.tsv into the
# gitignored assets/audio/ (no binaries in git). Columns: file, url, sha256
# (of the download, not of the derived file), licence, author, page, member
# (zip entry or -), trim (START+DURATION seconds or -, ffmpeg slice to wav).
#
# Downloads are cached in assets/audio/.cache and checked against the pinned
# sha256; a derived file is rebuilt only when it is missing. Idempotent.
# Offline: one line, exit 0 -- the game plays silence for missing sounds.
# Needs curl, sha256sum, unzip, ffmpeg (install.sh installs them).
# ============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly AUDIO_DIR="$REPO_ROOT/assets/audio"
readonly MANIFEST="$AUDIO_DIR/sources.tsv"
readonly CACHE="$AUDIO_DIR/.cache"
# Short fades so a sliced hoof strike starts and ends without a click.
readonly FADE_FILTER="afade=t=in:d=0.002,areverse,afade=t=in:d=0.025,areverse"

hash_ok() {
    local file="$1" want="$2"
    [[ -f "$file" ]] && [[ "$(sha256sum "$file" | cut -d' ' -f1)" == "$want" ]]
}

# Download url into the cache once; fail if the pinned hash does not match.
cached_source() {
    local url="$1" sha="$2"
    local target="$CACHE/${url##*/}"
    if hash_ok "$target" "$sha"; then
        printf '%s\n' "$target"
        return
    fi
    curl -fsSL --retry 2 -o "$target.part" "$url"
    mv "$target.part" "$target"
    if ! hash_ok "$target" "$sha"; then
        echo "fetch_audio: sha256 mismatch for $url" >&2
        return 1
    fi
    printf '%s\n' "$target"
}

# Copy (or slice) one manifest row's source into assets/audio/<file>.
derive() {
    local file="$1" source="$2" member="$3" trim="$4"
    local tmp input
    tmp="$(mktemp -d)"
    input="$source"
    if [[ "$member" != "-" ]]; then
        unzip -q -o "$source" "$member" -d "$tmp"
        input="$tmp/$member"
    fi
    if [[ "$trim" == "-" ]]; then
        # A hard link keeps one copy of a large direct download (wind).
        ln -f "$input" "$AUDIO_DIR/$file" 2>/dev/null || cp "$input" "$AUDIO_DIR/$file"
    else
        # atrim, not -ss: an input seek into an mp3 lands up to a frame late
        # and cuts off the very strike the slice is for.
        local cut="atrim=start=${trim%+*}:duration=${trim#*+},asetpts=PTS-STARTPTS"
        ffmpeg -v error -y -i "$input" -af "$cut,$FADE_FILTER" \
            -ac 1 -c:a pcm_s16le "$AUDIO_DIR/$file"
    fi
    rm -rf "$tmp"
}

main() {
    mkdir -p "$CACHE"
    if ! curl -fsI --max-time 10 https://opengameart.org >/dev/null 2>&1; then
        echo "fetch_audio: offline, sounds not fetched (the game runs silent)"
        return 0
    fi
    local file url sha _licence _author _page member trim source fetched=0
    while IFS=$'\t' read -r file url sha _licence _author _page member trim; do
        [[ "$file" == "file" || -z "$file" ]] && continue
        source="$(cached_source "$url" "$sha")"
        if [[ ! -s "$AUDIO_DIR/$file" ]]; then
            derive "$file" "$source" "$member" "$trim"
            fetched=$((fetched + 1))
        fi
    done <"$MANIFEST"
    echo "fetch_audio: $fetched new sound file(s), all hashes ok"
}

main "$@"
