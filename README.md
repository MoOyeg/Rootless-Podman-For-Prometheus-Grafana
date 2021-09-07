# Rootless-Podman-For-Prometheus-Grafana

## Ansible 

### References
https://github.com/ikke-t/podman-container-systemd

## Dependecies:<br/>
- ansible-galaxy collection install containers.podman

## Contains a set of bash scripts to enable the running and installation of Node Exporter, Prometheus and Grafana as rootless containers for Podman on Fedora 31.

## What do the scripts do<br/>
1 Show secure examples of how to run node-exporter, prometheus and grafana as containers via podman without using the root user on the host(rootless podman) and running a non-root user inside the container and making sure that non-root user is visible outside the container as appropriate<br/>
2 Shows how to use podman to generate systemd service files for node-exporter,prometheus and grafana<br/>
3 Shows how to run node-exporter,prometheus and grafana as systemd services tied to the non-root user account(i.e systemctl --user)<br/>

## Dependencies:<br/>
- Podman must be available
- Podman User namespaces must be enabled
- Access to Repos for Base Images and Files
- User running scripts must have sudo access(user does not have to be the non-root user podman will run containers with)




## Node_Exporter:
Run nodeexporter.sh

## Prometheus:
Run prometheus.sh

## Grafana:
Run grafana.sh<br/>


## Possible Issues: <br/>
- Error: opening file `cpu.max` for writing: Permission denied: OCI runtime permission denied error<br/>
  Likely Solution - https://github.com/containers/podman/issues/7959

- Error: Permission Denied on Sudo systemctl --user<br/>
  Likely Solution - https://access.redhat.com/solutions/4661741

- Error: Permission Denied on a Volume Mount in Container due to SELinux<br/>
  Likely Solution - Add a :Z to volume string for an selinux relabel see prometheus.sh for sample

- Error: Selinux Issue for Systemd<br/>
  sudo setsebool -P container_manage_cgroup on
  
