# Sourced by the apps' release scripts: finds the App Store Connect API key for ASC_KEY_ID and
# sets `key` to its .p8 — ASC_KEY_PATH, or the keychain item named ASC_KEY_KEYCHAIN_ITEM written
# to a temporary file only this user can read and removed when the script ends. Leaves `key`
# empty when ASC_KEY_ID is not set (docs/RELEASE.md).
key=
if [ -n "${ASC_KEY_ID:-}" ]; then
    key=${ASC_KEY_PATH:-}
    if [ -z "$key" ]; then
        key=$(mktemp -t outloud-asc-key)
        trap 'rm -f "$key"' EXIT INT TERM
        chmod 600 "$key"
        secret=$(security find-generic-password -s "$ASC_KEY_KEYCHAIN_ITEM" -w)
        # `security` prints a value with line breaks as hex.
        if printf '%s' "$secret" | grep -Eq '^([0-9a-f]{2})+$'; then
            printf '%s' "$secret" | xxd -r -p >"$key"
        else
            printf '%s\n' "$secret" >"$key"
        fi
        unset secret
        if ! grep -q 'BEGIN PRIVATE KEY' "$key"; then
            body=$(tr -d ' \n' <"$key")
            printf -- '-----BEGIN PRIVATE KEY-----\n%s\n-----END PRIVATE KEY-----\n' "$body" >"$key"
            unset body
        fi
    fi
fi
