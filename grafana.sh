#!/bin/bash
buildah from --name=grafana quay.io/prometheus/prometheus:v2.21.0
buildah copy grafana ./grafana.repo /etc/yum.repos.d/grafana.repo
