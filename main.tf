#-----------------------------------------
# PROVIDERS
#-----------------------------------------
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
  required_version = "~> 1.6"
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

#-----------------------------------------
# VARIABLES
#-----------------------------------------

variable "registry_url" {
  description = "URL of your Docker registry (e.g., registry.example.com)"
  type        = string
  default     = "rg.fr-par.scw.cloud/smartfire-devops-tests"
}

variable "registry_secret_name" {
  description = "Docker registry secret"
  type        = string
  default     = "registry-secret"
}

variable "registry_password" {
  description = "Docker registry password"
  type        = string
  default     = "069107f9-a03c-44a4-8d40-8d3f98d8173e"
}

data "template_file" "docker_config" {
  template = <<-EOT
    {
      "auths": {
        "${var.registry_url}": {
          "password": "${var.registry_password}"
        }
      }
    }
  EOT
}

#-----------------------------------------
# KUBERNETES SECRETS
#-----------------------------------------

resource "kubernetes_secret" "docker_registry_secret" {
  metadata {
    name = var.registry_secret_name
  }

  data = {
    ".dockerconfigjson" = data.template_file.docker_config.rendered
  }
}

#-----------------------------------------
# KUBERNETES DEPLOYMENT APP
#-----------------------------------------

resource "kubernetes_deployment" "php" {
  metadata {
    name = "php"
    labels = {
      app = "php"
    }
  }
  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "php"
      }
    }
    template {
      metadata {
        labels = {
          app = "php"
        }
      }

      spec {
        container {
          image = "rg.fr-par.scw.cloud/smartfire-devops-tests/php:1.0"
          name  = "wordpress"
          image_pull_policy = "Always"

          resources {
            limits = {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "50Mi"
            }
          }

        }
        image_pull_secrets {
          name = var.registry_secret_name
        }
                

      }
    }
  }
}

resource "kubernetes_deployment" "mysql" {
  metadata {
    name = "mysql"
    labels = {
      app = "mysql"
    }
  }
  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "mysql"
      }
    }
    template {
      metadata {
        labels = {
          app = "mysql"
        }
      }

      spec {
        container {
          image = "mysql:5.7"
          name  = "mysql"
          env {
            name = "MYSQL_ROOT_PASSWORD"
            value = "root"
          }
        }
      }
    }
  }
}



#-------------------------------------------------
# KUBERNETES DEPLOYMENT SERVICE
#-------------------------------------------------

resource "kubernetes_service" "lb" {
  metadata {
    name = "load-balancer"
  }
  spec {
    selector = {
      app = "php"
    }
    session_affinity = "ClientIP"
    port {
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }
}

resource "kubernetes_service" "node_port" {
  metadata {
    name = "node-port"
  }

  spec {
    selector = {
      app = "php"
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "NodePort" # Set the service type to NodePort
  }
}


resource "kubernetes_service" "cluster_ip_mysql" {
  metadata {
    name = "cluster-ip-mysql"
  }

  spec {
    selector = {
      app = "mysql"
    }

    port {
      port        = 3306
      target_port = 3306
    }

  }
}

#-------------------------------------------------
# KUBERNETES INGRESS
#-------------------------------------------------



#-------------------------------------------------
# KUBERNETES PVC
#-------------------------------------------------



#-------------------------------------------------
# KUBERNETES CONFIG MAPS
#-------------------------------------------------


