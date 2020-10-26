# Podman-PrometheusGrafana

## Contains a set of bash scripts to enable the running and installation of Node Exporter, Prometheus and Grafana as rootless containers for Podman on Fedora 31.

## Dependencies:
- Podman must be available
- Podman User namespaces must be enabled
- Access to Repos for Base Images and Files
- User running scripts must have sudo access

## Node_Exporter:
Run nodeexporter.sh

## Prometheus:
Run prometheus.sh

## Grafana:
Run grafana.sh


##Possible Issues:
- Error: opening file `cpu.max` for writing: Permission denied: OCI runtime permission denied error
  https://github.com/containers/podman/issues/7959

- Error: Permission Denied on Sudo systemctl --user
  https://access.redhat.com/solutions/4661741

- Error: Permission Denied on a Volume Mount in Container due to SELinux
  Add a :Z to volume string for an selinux relabel see prometheus.sh for sample

- Error: Selinux Issue for Systemd
  sudo setsebool -P container_manage_cgroup on
  
