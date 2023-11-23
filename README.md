# k3s-wordpress



## Process to deploy this Wordpress site 

Terraform script to deploy wordpress on k3s

1. Clone this repo

2. Init terraform repository
`terraform init`

3. Setup you kube_config 

4. Modify vars.tf if you need

5. terraform apply 


### Test objective: deploy a WordPress project on a Kubernetes cluster using Terraform

**Using a tool such as Lens to visualize what's happening in your cluster is
recommended.**

Useful information:
- The project is a WordPress 6.3
- It requires an Apache server - PHP 8.2
so you can use the Docker hub image: php:8.2-apache
- The project requires a MySQL 5.7 database
so you can use the Docker hub image: mysql:5.7

1. Docker - creating the project image (15 min)

Generate a Docker image including the project code, located in the "project" folder of the repo, and
send it to the private registry provided.

*Useful information: the code must be deposited in the /var/www/html folder of the image.*

You can connect to the private registry using the command :
docker login ghcr.io -u USER

Do not spend more than 15 min on this question in case of problems.


2. Kubernetes / Terraform (40 min)
If step 1 fails, use an official docker hub image, e.g.
php:8.2-apache.

Deploy on the Kubernetes cluster provided using Terraform, in the first step, the project in
minimal version:
- HTTP only (no SSL certificate generation) (see bonus questions)
- No data persistence (see bonus questions)
- No phpmyadmin (see bonus questions)
- For network management, you can use the LoadBalancer provided, as well as the pre-installed traefik ingress controler.

For access to the private registry, you can add the key in the spec of your
deployment template:
image_pull_secrets {
name = var.registry_secret_name
}

3. Bonus questions
- [x] Persist the project's wp-content/uploads folder, allowing images to be stored between several pod restarts.
- [x] Persist the wp-config.php file, to store database connection information database.
- [x] Persist database data. Useful information: the folder "/var/lib/mysql" folder.
- [x] Install a phpmyadmin to view database data.
- [ ] Use an SSL certificate for https access. During the debriefing, we can test your solution.
- [x] Add application resource usage protection.
- [ ] Change the listening port of the application container, for example to 8080.
- [x] Expose the application using a NodePort rather than a LoadBalancer.