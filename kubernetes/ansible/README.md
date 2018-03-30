![Kubernetes Logo](https://s28.postimg.org/lf3q4ocpp/k8s.png)

AutoDeploy Kubernetes based on [Kubernetes The Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way)
============================================
-   GCE only
-   Ansible
-   GCE Dynamic Inventory

Quick Start
-----------

- Fill `envioronment/gce.ini` with your Google Cloud project credentials 
- Set appropriate variables in `environment/group_vars/all`
- Run `$ ansible-playbook -i inventory/ main.yml`
- To ensure your Kubernetes cluster is functioning correctly pass [Smoke Test](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/4ca7c4504612d55d9c42c21632ca4f4a0e9b4a52/docs/13-smoke-test.md) manually
- You can cleanup used resources with `$ ansible-playbook -i inventory/ playbooks/cleanup.yml`

Variables
-----------

Example:
```
install_dir: /home/user/kubernetes
controllers_count: 2
workers_count: 2
service_cluster_ip_range: 10.32.0
kubernetes_subnet: 10.240.0
```
