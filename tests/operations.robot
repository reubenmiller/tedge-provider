*** Settings ***
Resource    ./resources/common.robot
Library    Cumulocity
Library    DeviceLibrary    bootstrap_script=bootstrap.sh

Suite Setup    Suite Setup
Test Teardown    Collect Logs

*** Test Cases ***

Set Log Types
    ${operation}=    Cumulocity.Execute Shell Command    sudo log_provider export-all
    Operation Should Be SUCCESSFUL    ${operation}
    Cumulocity.Should Support Log File Types    journald/tedge-agent    journald/tedge-mapper-c8y    journald/mosquitto    container/nginx    container/tedgecontainer    includes=${True}

Get Log File - journald/tedge-agent
    Get Log File    journald/tedge-agent

Get Log File - journald/tedge-mapper-c8y
    Get Log File    journald/tedge-mapper-c8y

Get Log File - container/nginx
    Get Log File    container/nginx

Get Log File - container/tedgecontainer
    Get Log File    container/tedgecontainer

*** Keywords ***

Suite Setup
    ${DEVICE_SN}=    Setup
    Set Suite Variable    $DEVICE_SN
    Cumulocity.External Identity Should Exist    ${DEVICE_SN}

    # Create some containers for usage in tests
    DeviceLibrary.Execute Command    sudo podman run --rm -t -d --name nginx docker.io/nginx
    DeviceLibrary.Execute Command    sudo podman run --rm -t -d --name tedgecontainer ghcr.io/thin-edge/tedge:1.3.1 tedge-agent

Get Log File
    [Arguments]    ${log_type}
    ${operation}=    Cumulocity.Get Log File    ${log_type}
    Operation Should Be SUCCESSFUL    ${operation}

Collect Logs
    Collect Workflow Logs
    Collect Systemd Logs

Collect Systemd Logs
    Execute Command    sudo journalctl -n 10000

Collect Workflow Logs
    Execute Command    head -n-0 /var/log/tedge/agent/*
