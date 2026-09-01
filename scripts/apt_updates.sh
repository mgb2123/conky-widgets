#!/bin/bash
apt list --upgradable 2>/dev/null | tail -n +2 | wc -l
