
provider "kubernetes" {
  config_path = "kube_config"
  config_context = "microk8s"
  config_context_cluster = "microk8s-cluster"

  # load_config_file = "false"

  # host = "https://10.0.0.210"
}

resource "kubernetes_namespace" "sprint_namespace" {
  metadata {
    name = "sprint"
  }
}

output "web_service_ip" {
  value = "${kubernetes_service.sprint_service.spec.0.cluster_ip}"
}

output "db_service_ip" {
  value = "${kubernetes_service.sprint_db_service.spec.0.cluster_ip}"
}

resource "kubernetes_deployment" "sprint_database_deployment" {
  metadata {
    name = "sprintdb"
    namespace = "${kubernetes_namespace.sprint_namespace.metadata.0.name}"
    labels = {
      App = "SprintDB"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        App = "SprintDB"
      }
    }

    template {
      metadata {
        labels = {
          App = "SprintDB"
        }
      }

      spec {
        container {
          image = "mysql:5.6"
          name  = "sprintdb"

          port {
            container_port = 3306
          }

          env = [
            {
              "name" = "MYSQL_ROOT_PASSWORD"
              "value" = "sprintadmin"
            },
            {
              "name" = "MYSQL_DATABASE"
              "value" = "sprintdb"
            },
            {
              "name" = "MYSQL_USER"
              "value" = "sprintusr"
            },
            {
              "name" = "MYSQL_PASSWORD"
              "value" = "sprintpwd"
            }
          ]

          resources {
            limits {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests {
              cpu    = "250m"
              memory = "50Mi"
            }
          }
        }


      }
    }
  }
}

resource "kubernetes_deployment" "sprint_deployment" {
  metadata {
    name = "sprint"
    namespace = "${kubernetes_namespace.sprint_namespace.metadata.0.name}"
    labels = {
      app = "Sprint"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        App = "Sprint"
      }
    }

    template {
      metadata {
        labels = {
          App = "Sprint"
        }
      }

      spec {
        container {
          image = "vinik/sprint:0.1"
          name  = "sprint"

          port {
            container_port = 80
          }

          env = [
            {
              "name" = "OPENSHIFT_MYSQL_DB_HOST"
              "value" = "${kubernetes_service.sprint_db_service.spec.0.cluster_ip}"
            },
            {
              "name" = "OPENSHIFT_MYSQL_DB_PORT"
              "value" = "3306"
            },
            {
              "name" = "OPENSHIFT_GEAR_NAME"
              "value" = "sprintdb"
            },
            {
              "name" = "OPENSHIFT_MYSQL_DB_USERNAME"
              "value" = "sprintusr"
            },
            {
              "name" = "OPENSHIFT_MYSQL_DB_PASSWORD"
              "value" = "sprintpwd"
            }
          ]

          resources {
            limits {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests {
              cpu    = "250m"
              memory = "50Mi"
            }
          }

          volume_mount {
            mount_path = "/var/www/site/app/tmp"
            name = "exampleclaimname"
          }
        }
        volume {
          name = "exampleclaimname"
        }
      }
    }
  }
}

resource "kubernetes_service" "sprint_db_service" {
  metadata {
    name = "sprintdb"
    namespace = "${kubernetes_namespace.sprint_namespace.metadata.0.name}"
  }
  spec {
    selector = {
      App = "${kubernetes_deployment.sprint_database_deployment.spec.0.template.0.metadata.0.labels.App}"
    }
    port {
      node_port = 32306
      port        = 3306
      target_port = 3306
    }

    type = "NodePort"
  }
}

resource "kubernetes_service" "sprint_service" {
  metadata {
    name = "sprint"
    namespace = "${kubernetes_namespace.sprint_namespace.metadata.0.name}"
  }
  spec {
    selector = {
      App = "${kubernetes_deployment.sprint_deployment.spec.0.template.0.metadata.0.labels.App}"
    }
    port {
      node_port = 30201
      port        = 80
      target_port = 80
    }

    type = "NodePort"
  }
}

resource "kubernetes_persistent_volume_claim" "example" {
  metadata {
    name = "exampleclaimname"
    namespace = "${kubernetes_namespace.sprint_namespace.metadata.0.name}"
  }
  spec {
    storage_class_name = "microk8s-hostpath"
    access_modes = ["ReadWriteMany"]
    resources {
      requests = {
        storage = "1Gi"
      }
    }
    volume_name = "${kubernetes_persistent_volume.example.metadata.0.name}"
  }
}

resource "kubernetes_persistent_volume" "example" {
  metadata {
    name = "examplevolumename"
  }
  spec {
    storage_class_name = "microk8s-hostpath"
    capacity = {
      storage = "2Gi"
    }
    access_modes = ["ReadWriteMany"]
    persistent_volume_source {
      local {
        path = "/tmp/foo/"
      }
    }

    node_affinity {
      required {
        node_selector_term {
          match_expressions = [
            {
              key = "kubernetes.io/hostname"
              operator = "In"
              values = ["otacon"]
            }

          ]
        }
      }
    }
  }
}
