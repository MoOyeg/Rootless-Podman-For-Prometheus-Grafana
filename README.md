# Rootless-Podman-For-Prometheus-Grafana

## Status: Not working
##Contains a set of bash scripts to enable the running and installation of Node Exporter, Prometheus and Grafana as rootless containers for Podman on Fedora 31

## What do the scripts do

1 Show secure examples of how to run node-exporter, prometheus and grafana as containers via podman without using the root user on the host(rootless podman) and running a non-root user inside the container and making sure that non-root user is visible outside the container as appropriate  
2 Shows how to use podman to generate systemd service files for node-exporter,prometheus and grafana  
3 Shows how to run node-exporter,prometheus and grafana as systemd services tied to the non-root user account(i.e systemctl --user)  

## Dependencies

- Podman must be available  
- Podman User namespaces must be enabled  
- Access to Repos for Base Images and Files
- User running scripts must have sudo access(user does not have to be the non-root user podman will run containers with)  
- Grafana script required buildah

## Node_Exporter

Run ```sudo nodeexporter.sh```

## Prometheus

Run ```sudo prometheus.sh```

## Grafana

Run ```sudo grafana.sh```

## Possible Issues

- Error: opening file `cpu.max` for writing: Permission denied: OCI runtime permission denied error  
  Likely Solution - https://github.com/containers/podman/issues/7959

- Error: Permission Denied on Sudo systemctl --user  
  Likely Solution - <https://access.redhat.com/solutions/4661741>

- Error: Permission Denied on a Volume Mount in Container due to SELinux  
  Likely Solution - Add a :Z to volume string for an selinux relabel see prometheus.sh for sample

- Error: Selinux Issue for Systemd  
  sudo setsebool -P container_manage_cgroup on
