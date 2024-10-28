#!/bin/sh
set -e

PROVIDERS_DIR=${PROVIDERS_DIR:-/usr/lib/tedge-log-provider/providers}
DATE_FROM=${DATE_FROM:-"24h"}
DATE_TO=${DATE_TO:-"0m"}
MAX_LINES=${MAX_LINES:-1000}
SEARCH_TEXT=
UPLOAD_URL=
CHECK_EXIT_CODE=1
POSITIONAL_ARGS=
PROVIDER=
PROVIDER_NAME=
SERVICE=

# Support sending the service name via the --text field
USE_SEARCH_TEXT_FOR_SERVICE=${USE_SEARCH_TEXT_FOR_SERVICE:-0}

TEDGE_LOG_PLUGIN=/etc/tedge/plugins/tedge-log-plugin.toml

if [ -f /etc/tedge-log-provider.env ]; then
    # shellcheck disable=SC1091
    . /etc/tedge-log-provider.env
fi

ACTION="$1"
shift

parse_provider() {
    echo "$1" | cut -d/ -f1
}

parse_service() {
    case "$1" in
        */*)
            echo "$1" | cut -d/ -f2-
            ;;
        *)
            # No service
            ;;
    esac
}

while [ $# -gt 0 ]; do
    case "$1" in
        --type)
            value="$2"
            PROVIDER_NAME=$(parse_provider "$value")
            PROVIDER="$PROVIDERS_DIR/$PROVIDER_NAME"
            SERVICE=$(parse_service "$value")
            shift
            ;;
        --since)
            DATE_FROM="$2"
            shift
            ;;
        --until)
            DATE_TO="$2"
            shift
            ;;
        --text)
            SEARCH_TEXT="$2"
            shift
            ;;
        --max-lines|-n)
            MAX_LINES="$2"
            shift
            ;;
        --url)
            UPLOAD_URL="$2"
            shift
            ;;
        --check-exit-code)
            CHECK_EXIT_CODE="$2"
            shift
            ;;
        --*|-*)
            ;;
        *)
            POSITIONAL_ARGS="$POSITIONAL_ARGS $1"
    esac
    shift
done
set -- "$POSITIONAL_ARGS"

log() {
    echo "$@" >&2
}

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

provider_check() {
    if [ ! -f "$PROVIDER" ]; then
        log "Provider not found. provider=$PROVIDER"
        return 1
    fi

    if [ ! -x "$PROVIDER" ]; then
        log "Provider is not marked as an executable. Please run 'chmod +x \"$PROVIDER\"'"
        return 1
    fi
}

check() {
    log "Checking for log provider. provider=$PROVIDER"
    if ! provider_check; then
        exit "$CHECK_EXIT_CODE"
    fi
    printf ':::begin-tedge:::\n{"provider":"%s","service":"%s"}\n:::end-tedge:::\n' "$PROVIDER_NAME" "$SERVICE"
}

provider_run() {
    log "Executing log upload provider. provider=$PROVIDER_NAME, service=$SERVICE"

    provider_check

    if [ -z "$UPLOAD_URL" ]; then
        fail "UPLOAD_URL is empty. An upload url is mandatory"
    fi

    # Support a mode where the service name is supplied in the search text
    # in cases where the log type list is fixed, therefore allow users to supply any name
    if [ "$USE_SEARCH_TEXT_FOR_SERVICE" = 1 ]; then
        log "Using SEARCH_TEXT to set the SERVICE field"
        SERVICE="$SEARCH_TEXT"
        SEARCH_TEXT=
    fi

    TMP_LOG_DIR=$(mktemp -d)

    # Ensure directory is always deleted afterwards
    trap 'rm -rf -- "$TMP_LOG_DIR"' EXIT
    TMP_FILE="${TMP_LOG_DIR}/${PROVIDER_NAME}_${SERVICE}_$(date -Iseconds).log"

    # Add log header to give information about the contents
    {
        echo "---------------- log parameters ----------------------"
        echo "searchText: $SEARCH_TEXT"
        echo "dateFrom:   $DATE_FROM"
        echo "dateTo:     $DATE_TO"
        echo "maxLines:   $MAX_LINES"
        echo "provider:   $PROVIDER_NAME"
        echo "service:    $SERVICE"
        echo "command:    $PROVIDER logs --service \"$SERVICE\" --max-lines \"$MAX_LINES\" --since \"$DATE_FROM\" --until \"$DATE_TO\" --text \"$SEARCH_TEXT\""
        echo "------------------------------------------------------"
        echo
    } > "$TMP_FILE"

    # TODO: Should filtering by applied against the results, or should each provider apply the filter
    "$PROVIDER" logs --service "$SERVICE" --max-lines "$MAX_LINES" --since "$DATE_FROM" --until "$DATE_TO" --text "$SEARCH_TEXT" \
    | sed -e 's/\x1b\[[0-9;]*m//g' \
    | head -n"$MAX_LINES" >> "$TMP_FILE"

    log "Uploading log file to $UPLOAD_URL"
    # Use mtls if configured
    if [ -f "$(tedge config get http.client.auth.key_file)" ] && [ -f "$(tedge config get http.client.auth.cert_file)" ]; then
        # Upload using mtl
        echo "Uploading log file using mtls"
        curl -4 -sfL \
            -XPUT \
            --data-binary "@$TMP_FILE" \
            --capath "$(tedge config get http.ca_path)" \
            --key "$(tedge config get http.client.auth.key_file)" \
            --cert "$(tedge config get http.client.auth.cert_file)" \
            "$UPLOAD_URL"
    else
        # Upload using default
        curl -4 -sfL -XPUT --data-binary "@$TMP_FILE" "$UPLOAD_URL"
    fi
}

provider_list() {
    #
    # List which logs can be requested from the service
    #
    provider_check
    "$PROVIDER" list
}

provider_list_all () {
    #
    # List all of the log types supported by all providers
    #
    for provider in "$PROVIDERS_DIR/"*; do
        log "Running: $provider list"
        if ! "$provider" list; then
            log "Ignoring provider: $provider"
        fi
    done
}

export_all_settings() {
    #
    # Add each provider type to the tedge-log-plugin.toml
    #
    log "Adding log types to $TEDGE_LOG_PLUGIN"
    for provider in "$PROVIDERS_DIR/"*; do
        log "Executing: $provider list"
        for name in $("$provider" list); do
            if ! grep -q "type = \"$name\"" "$TEDGE_LOG_PLUGIN"; then
                log "Appending to tedge-log-plugin. type=$name"
                provider_name=$(basename "$provider")
                printf '[[files]]\ntype = "%s"\npath = "provider:%s"\n\n' "$name" "$provider_name" >> "$TEDGE_LOG_PLUGIN"
            else
                log "Already added. type=$name"
            fi
        done
    done
}

#
# Main
#
case "$ACTION" in
    check)
        check
        ;;
    list)
        provider_list
        ;;
    list-all)
        provider_list_all
        ;;
    export-all)
        export_all_settings
        ;;
    run)
        provider_run
        ;;
esac
