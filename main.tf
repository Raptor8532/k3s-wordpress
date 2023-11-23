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
  config_path = "~/.kube/k3s_config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/k3s_config"
  }
}

#-----------------------------------------
# VARIABLES
#-----------------------------------------
variable "registry_secret_name" {
  description = "Container registry secret"
  type        = string
  default     = "registry-secret"
}

variable "registry_server" {
  description = "URL of your Container registry (e.g., registry.example.com)"
  type        = string
  default     = "ghcr.io"
}

variable "registry_username" {
  description = "Container registry password"
  type        = string
  sensitive   = true
}

variable "registry_password" {
  description = "Container registry password"
  type        = string
  sensitive   = true
}

data "template_file" "docker_config" {
  template = <<-EOT
{
  "auths": {
    "${var.registry_server}": {
      "username": "${var.registry_username}",
      "password": "${var.registry_password}",
      "auth": "${base64encode("${var.registry_username}:${var.registry_password}")}"
    }
  }
}
EOT
}

#-----------------------------------------
# KUBERNETES SECRETS
#-----------------------------------------

resource "kubernetes_secret" "container_registry_secret" {
  metadata {
    name = var.registry_secret_name
  }

  data = {
    ".dockerconfigjson" = "${data.template_file.docker_config.rendered}"
  }

  type = "kubernetes.io/dockerconfigjson"
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

  timeouts {
    create = "3m"
    update = "2m"
    delete = "2m"
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
          image             = "ghcr.io/raptor8532/php_wordpress:latest"
          name              = "wordpress"
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
          volume_mount {
            name       = "uploads-volume"
            mount_path = "/var/www/html/wp-content/uploads" # Path inside pod
          }
          volume_mount {
            name       = "wp-config"
            mount_path = "/var/www/html/wp-config.php"
            sub_path   = "wp-config.php"
            read_only  = true
          }
        }
        image_pull_secrets {
          name = var.registry_secret_name
        }
        volume {
          name = "uploads-volume"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.wp_content_uploads_claim.metadata[0].name
          }
        }
        volume {
          name = "wp-config"
          config_map {
            name = "wp-config"
          }
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
            name  = "MYSQL_ROOT_PASSWORD"
            value = "root"
          }
          env {
            name  = "MYSQL_USER"
            value = "wordpress"
          }
          env {
            name  = "MYSQL_PASSWORD"
            value = "wordpress"
          }
          env {
            name  = "MYSQL_ALLOW_EMPTY_PASSWORD"
            value = "yes"
          }
          env {
            name  = "MYSQL_DATABASE"
            value = "wordpress"
          }
          volume_mount {
            name       = "mysql-db"
            mount_path = "/var/lib/mysql" # Path inside pod
          }
        }
        volume {
          name = "mysql-db"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.mysql_claim.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_deployment" "phpmyadmin" {
  metadata {
    name = "phpmyadmin"
    labels = {
      app = "phpmyadmin"
    }
  }
  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "phpmyadmin"
      }
    }
    template {
      metadata {
        labels = {
          app = "phpmyadmin"
        }
      }

      spec {
        container {
          image = "phpmyadmin/phpmyadmin:latest"
          name  = "phpmyadmin"
          env {
            name  = "PMA_HOST"
            value = "svc-mysql:3306"
          }
          env {
            name  = "PMA_PASSWORD"
            value = "wordpress"
          }
          env {
            name  = "PMA_USER"
            value = "wordpress"
          }
        }
      }
    }
  }
}



#-------------------------------------------------
# KUBERNETES DEPLOYMENT SERVICE
#-------------------------------------------------

resource "kubernetes_service" "node_port" {
  metadata {
    name = "node-port-php"
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

resource "kubernetes_service" "node_port_phpmyadmin" {
  metadata {
    name = "node-port-phpmyadmin"
  }

  spec {
    selector = {
      app = "phpmyadmin"
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
    name = "svc-mysql"
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

#-----------------------------------------
# KUBERNETES PERSISTENT VOLUME (PV)
#-----------------------------------------
resource "kubernetes_persistent_volume" "wp_content_uploads" {
  metadata {
    name = "wp-content-uploads-pv"
  }
  spec {
    storage_class_name = "default"
    capacity = {
      storage = "200Mi" # Taille du volume
    }
    access_modes = ["ReadWriteMany"]
    persistent_volume_source {
      host_path {
        path = "/home/ubuntu/wp-content/uploads" # Chemin sur le nœud hôte
      }
    }
  }
}

resource "kubernetes_persistent_volume" "mysql-pv" {
  metadata {
    name = "mysql-pv"
  }
  spec {
    storage_class_name = "default"
    capacity = {
      storage = "200Mi" # Taille du volume
    }
    access_modes = ["ReadWriteMany"]
    persistent_volume_source {
      host_path {
        path = "/home/ubuntu/mysql" # Chemin sur le nœud hôte
      }
    }
  }
}
#-----------------------------------------
# KUBERNETES PERSISTENT VOLUME CLAIM (PVC)
#-----------------------------------------

resource "kubernetes_persistent_volume_claim" "wp_content_uploads_claim" {
  metadata {
    name = "wp-content-uploads-pvc"
  }

  spec {
    access_modes       = ["ReadWriteMany"]
    storage_class_name = "default"
    resources {
      requests = {
        storage = "200Mi" # Taille du volume correspondant à celle du PV
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "mysql_claim" {
  metadata {
    name = "mysql-pvc"
  }

  spec {
    access_modes       = ["ReadWriteMany"]
    storage_class_name = "default"
    resources {
      requests = {
        storage = "200Mi" # Taille du volume correspondant à celle du PV
      }
    }
  }
}

#-------------------------------------------------
# KUBERNETES CONFIG MAPS
#-------------------------------------------------

resource "kubernetes_config_map" "wp_config" {
  metadata {
    name = "wp-config"
  }

  data = {
    "wp-config.php" = "${file("wp-config.php")}"
  }
}

