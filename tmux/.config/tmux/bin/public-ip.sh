#!/bin/bash

curl -4s --max-time 3 https://icanhazip.com/ | curl -4s --max-time 3 https://ifconfig.me/
