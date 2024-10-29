# Plugins

thin-edge.io research into using extendable providers for:
* tedge-log-plugin

## tedge-log-provider

### Adding a provider

Providers can be added to the following directory.

```sh
/usr/lib/tedge-log-provider/providers
```

Each provider must follow the following command signatures:

```sh
# List the types that should be added
myprovider list

# Fetch the logs given the search parameters
myprovider logs [--service "<service>"] [--since "<since>"] [--until "<until>"] [--text <text>] [--max-lines <max_lines>]
```

### Example log provider

A log provider can execute any command to retrieve and print the logs. The `log_provider` is then responsible for integrating the provider with thin-edge.io.

The following shows how to add your own log provider to retrieve logs from a custom source (e.g. sqlite, or some other 3rd party interface).

1. Create a provider file

    **File: /usr/lib/tedge-log-provider/providers/plclog**

    ```sh
    #!/bin/sh
    set -e

    SEARCH_TEXT=
    DATE_FROM=${DATE_FROM:-"24h"}
    DATE_TO=${DATE_TO:-"0m"}
    MAX_LINES=${MAX_LINES:-1000}
    SERVICE=

    # Arg parsing
    ACTION="$1"
    shift
    while [ $# -gt 0 ]; do
        case "$1" in
            --service)
                SERVICE="$2"
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
            --help|-h)
                ;;
            *)
                ;;
        esac
        shift
    done

    list() {
        # Print 1 item per line to stdout, with the format "<provider>/<log_instance>"
        provider_name=$(basename "$0")
        echo "$provider_name/instance1"
        echo "$provider_name/instace2"
    }

    logs() {
        # Fetch the logs and print the log contents to stdout
        # Additional logging should be written to stderr
        echo "Fetching logs. Parameters: SERVICE=$SERVICE, SINCE=$DATE_FROM, UNTIL=$DATE_TO, TEXT=$SEARCH_TEXT, MAX_LINES=$MAX_LINES" >&2

        echo "TODO: Run your logic to print the log contents to stdout"
    }

    #
    # Main
    #
    case "$ACTION" in
        logs)
            logs
            ;;
        list)
            list
            ;;
        *)
            echo "Unsupported command" >&2
            exit 1
            ;;
    esac
    ```

2. Allow the provider to be executed

    ```sh
    chmod a+x /usr/lib/tedge-log-provider/providers/plclog
    ```

3. Add the log types to the `tedge-log-plugin.toml` from each provider by running the following command:

    ```sh
    log_provider export-all
    ```
