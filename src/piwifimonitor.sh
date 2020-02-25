#!/bin/bash
set -o nounset

CONFIG_PATH=/etc/piwifimonitor_config
LOG_PATH=/var/log/piwifimonitor

# gpioset runs in the background. Make sure those processes die if we exit so
# that we have a clean exit.
trap "exit" SIGKILL SIGTERM
trap "kill 0" EXIT 

# TODO: Trap SIGHUP and reload the config. Should reload during wifi monitoring.

read_args() {
    DO_UNIT_TESTS=0

    for arg in "$@"; do
        case "$arg" in
            --test)
                DO_UNIT_TESTS=1
                ;;

            *)
                exit 1
                ;;
        esac
    done
}

log() {
    echo "[$(date +"%F %T")] $1" | tee -a "$LOG_PATH"
}

log_error() {
    log "$1" >&2
}


main() {
    load_config
    if [[ $? -ne 0 ]]; then
        exit 1
    fi

    print_config

    while true; do
        power_on
        monitor_wifi
        power_off
    done
}

load_config() {
    if [[ -e "$CONFIG_PATH" ]]; then
        . "$CONFIG_PATH"
    fi

    # Default values for the configurable parameters
    GPIO_CHIP_NAME=${GPIO_CHIP_NAME:-}
    if [[ -z "$GPIO_CHIP_NAME" ]]; then
        log_error "GPIO_CHIP_NAME must be set"
        return 1
    fi

    MODEM_GPIO_OFFSET=${MODEM_GPIO_OFFSET:-}
    if [[ -z "$MODEM_GPIO_OFFSET" || "$(is_int $MODEM_GPIO_OFFSET)" -eq 0  ]]; then
        log_error "MODEM_GPIO_OFFSET must be a positive integer"
        return 1
    fi

    ROUTER_GPIO_OFFSET=${ROUTER_GPIO_OFFSET:-}
    if [[ -z "$ROUTER_GPIO_OFFSET" || "$(is_int $ROUTER_GPIO_OFFSET)" -eq 0  ]]; then
        log_error "ROUTER_GPIO_OFFSET must be a positive integer"
        return 1
    fi

    # Any non-zero value is okay to signify active low
    MODEM_GPIO_ACTIVE_LOW=${MODEM_GPIO_ACTIVE_LOW:-0}
    ROUTER_GPIO_ACTIVE_LOW=${ROUTER_GPIO_ACTIVE_LOW:-0}
    MODEM_GPIO_INVERTED=${MODEM_GPIO_INVERTED:-0}
    ROUTER_GPIO_INVERTED=${ROUTER_GPIO_INVERTED:-0}

    if [[ "$MODEM_GPIO_INVERTED" -eq 0 ]]; then
        MODEM_GPIO_HIGH_VALUE=1
    else
        MODEM_GPIO_HIGH_VALUE=0
    fi

    if [[ "$ROUTER_GPIO_INVERTED" -eq 0 ]]; then
        ROUTER_GPIO_HIGH_VALUE=1
    else
        ROUTER_GPIO_HIGH_VALUE=0
    fi

    ROUTER_POWER_ON_DELAY=${ROUTER_POWER_ON_DELAY:-60}
    if [[ "$(is_int $ROUTER_POWER_ON_DELAY)" -eq 0 ]]; then
        log_error "ROUTER_POWER_ON_DELAY must be a positive integer"
        return 1
    fi

    POWER_OFF_DELAY=${POWER_OFF_DELAY:-10}
    if [[ "$(is_int $POWER_OFF_DELAY)" -eq 0 ]]; then
        log_error "POWER_OFF_DELAY must be a positive integer"
        return 1
    fi

    # Google, Level3, and OpenDNS servers. It's highly unlikely that all of
    # these will be down at the same time. As long as one is up, we're good
    PING_ADDRESSES=${PING_ADDRESSES:-8.8.8.8 4.2.2.1 208.67.222.222}

    POWER_ON_WIFI_TIMEOUT=${POWER_ON_WIFI_TIMEOUT:-60}
    if [[ "$(is_int $POWER_ON_WIFI_TIMEOUT)" -eq 0 ]]; then
        log_error "POWER_ON_WIFI_TIMEOUT must be a positive integer"
        return 1
    fi

    WIFI_MONITOR_INTERVAL=${WIFI_MONITOR_INTERVAL:-60}
    if [[ "$(is_int $WIFI_MONITOR_INTERVAL)" -eq 0 ]]; then
        log_error "WIFI_MONITOR_INTERVAL must be a positive integer"
        return 1
    fi

    return 0
}

is_int() {
    if [[ "$1" =~ ^[0-9]+$ ]]; then
        echo 1
    else
        echo 0
    fi
}

print_config() {
    log "GPIO_CHIP_NAME=$GPIO_CHIP_NAME"
    log "MODEM_GPIO_OFFSET=$MODEM_GPIO_OFFSET"
    log "ROUTER_GPIO_OFFSET=$ROUTER_GPIO_OFFSET"
    log "MODEM_GPIO_ACTIVE_LOW=$MODEM_GPIO_ACTIVE_LOW"
    log "ROUTER_GPIO_ACTIVE_LOW=$ROUTER_GPIO_ACTIVE_LOW"
    log "MODEM_GPIO_INVERTED=$MODEM_GPIO_INVERTED"
    log "ROUTER_GPIO_INVERTED=$ROUTER_GPIO_INVERTED"
    log "ROUTER_POWER_ON_DELAY=$ROUTER_POWER_ON_DELAY"
    log "POWER_OFF_DELAY=$POWER_OFF_DELAY"
    log "PING_ADDRESSES=$PING_ADDRESSES"
    log "POWER_ON_WIFI_TIMEOUT=$POWER_ON_WIFI_TIMEOUT"
    log "WIFI_MONITOR_INTERVAL=$WIFI_MONITOR_INTERVAL"
}

power_on() {
    power_on_modem
    sleep $ROUTER_POWER_ON_DELAY
    power_on_router
}

power_off() {
    log "Powering off modem and router..."
    kill "$modem_pid" "$router_pid"
    sleep $POWER_OFF_DELAY
}

power_on_modem() {
    log "Powering on modem..."
    cmd="gpioset --mode=signal $GPIO_CHIP_NAME"

    if [[ "$MODEM_GPIO_ACTIVE_LOW" -ne 0 ]]; then
        cmd="$cmd --active-low"
    fi

    cmd="$cmd $MODEM_GPIO_OFFSET=$MODEM_GPIO_HIGH_VALUE"
    $cmd &
    modem_pid=$!
}

power_on_router() {
    log "Powering on router..."
    cmd="gpioset --mode=signal $GPIO_CHIP_NAME"

    if [[ "$ROUTER_GPIO_ACTIVE_LOW" -ne 0 ]]; then
        cmd="$cmd --active-low"
    fi

    cmd="$cmd $ROUTER_GPIO_OFFSET=$ROUTER_GPIO_HIGH_VALUE"
    $cmd &
    router_pid=$!
}

monitor_wifi() {
    wait_for_wifi
    if [[ $? -ne 0 ]]; then return; fi

    wait_for_no_wifi
}

wait_for_wifi() {
    log "Waiting $POWER_ON_WIFI_TIMEOUT seconds for Wi-Fi to become available..."
    local timeout=$(( $(date +%s) + $POWER_ON_WIFI_TIMEOUT))

    while [[ $(date +%s) -lt $timeout ]]
        test_ping
        if [[ $? -eq 0 ]]; then
            log "Wi-Fi is available"
            return 0
        fi
    do
        continue
    done

    log "Wi-Fi is not available"
    return 1
}

wait_for_no_wifi() {
    log "Waiting for Wi-Fi to become unavailable..."

    while true; do
        test_ping
        if [[ $? -ne 0 ]]; then
            log "Wi-Fi is not available"
            break
        fi
        sleep $WIFI_MONITOR_INTERVAL
    done
}

test_ping() {
    # Loop through the addresses checking that we can ping at least one of them.
    for host in $PING_ADDRESSES; do
        ping -i 1 -w 3 "$host" > /dev/null
        if [[ $? -eq 0 ]]; then
            return 0
        fi
    done

    return 1
}

################################################################################
# Unit tests and helpers
################################################################################

assert_int_eq() {
    if [[ "$1" -ne "$2" ]]; then
        echo "ASSERTION FAILED: $1 != $2"
        caller 0
        return 1
    fi

    return 0
}

do_unit_tests() {
    test_is_int
}

test_is_int() {
    local failures=0

    assert_int_eq 1 $(is_int 1)
    failures=$(($failures+$?))

    assert_int_eq 1 $(is_int 10)
    failures=$(($failures+$?))

    assert_int_eq 1 $(is_int 100)
    failures=$(($failures+$?))

    assert_int_eq 0 $(is_int "a")
    failures=$(($failures+$?))

    assert_int_eq 0 $(is_int "abc")
    failures=$(($failures+$?))

    assert_int_eq 0 $(is_int "1a")
    failures=$(($failures+$?))

    assert_int_eq 0 $(is_int "a1")
    failures=$(($failures+$?))

    echo "is_int: $failures failures"
}

################################################################################
# Entry point
################################################################################
read_args $@
if [[ "$DO_UNIT_TESTS" -eq 1 ]]; then
    do_unit_tests
else
    main
fi