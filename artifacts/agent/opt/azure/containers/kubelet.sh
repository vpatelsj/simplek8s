#!/bin/bash

sed -i "s|apparmor_parser|d|g" "/etc/systemd/system/kubelet.service"