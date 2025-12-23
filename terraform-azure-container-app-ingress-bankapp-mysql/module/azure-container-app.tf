resource "azurerm_resource_group" "aca_rg" {
  name     = "${var.prefix}-rg"
  location = var.location

  tags = {
    Environment = var.env
  }
}

resource "azurerm_log_analytics_workspace" "aca_log_analytics_workspace" {
  name                = "${var.prefix}-log-analytics-workspace"
  location            = azurerm_resource_group.aca_rg.location
  resource_group_name = azurerm_resource_group.aca_rg.name

  tags = {
    Environment = var.env
  }
}

resource "azurerm_container_app_environment" "aca_environment" {
  name                       = "${var.prefix}-environment"
  location                   = azurerm_resource_group.aca_rg.location
  resource_group_name        = azurerm_resource_group.aca_rg.name
  infrastructure_subnet_id   = azurerm_subnet.azure_container_apps.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.aca_log_analytics_workspace.id

  tags = {
    Environment = var.env
  }
}

resource "azurerm_container_app_environment_certificate" "ssl_certificate" {
  name                         = "${var.prefix}-certificate"
  container_app_environment_id = azurerm_container_app_environment.aca_environment.id
  certificate_blob_base64      = filebase64("mykey.pfx")
  certificate_password         = var.certificate_password
}

resource "azurerm_storage_account" "azure_file_share" {
  name                     = "azurestorage22122025"
  resource_group_name      = azurerm_resource_group.aca_rg.name
  location                 = azurerm_resource_group.aca_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    Environment = var.env
  }
}

resource "azurerm_storage_share" "azure_storageshare" {
  name               = "${var.prefix}-storageshare"
  storage_account_id = azurerm_storage_account.azure_file_share.id
  quota              = 5  ### Size in GB
}

resource "azurerm_container_app_environment_storage" "container_app_storage_mount" {
  name                         = "${var.prefix}-storagemount"
  container_app_environment_id = azurerm_container_app_environment.aca_environment.id
  account_name                 = azurerm_storage_account.azure_file_share.name
  share_name                   = azurerm_storage_share.azure_storageshare.name
  access_key                   = azurerm_storage_account.azure_file_share.primary_access_key
  access_mode                  = "ReadWrite"
}

resource "azurerm_container_app" "aca_mysql_app" {
  name                         = "mysql-service"    ###"${var.prefix}-mysql"

  container_app_environment_id = azurerm_container_app_environment.aca_environment.id
  resource_group_name          = azurerm_resource_group.aca_rg.name
  revision_mode                = "Single"

#  registry {
#    server               = "docker.io"
#    username             = "dockerIOUserName"
#    password_secret_name = "docker-io-pass"
#  }

  ingress {
    allow_insecure_connections = false
    external_enabled           = false
    target_port                = 3306
    exposed_port               = 3306
    transport                  = "tcp"
    traffic_weight {
      percentage = 100
      latest_revision = true
    }

  }

  template {
    container {
      name   = "${var.prefix}-mysql"
      image  = "mysql:8.0"
      cpu    = 0.5
      memory = "1Gi"
      volume_mounts {
        name = azurerm_storage_share.azure_storageshare.name
        path = "/${azurerm_storage_share.azure_storageshare.name}"
      }
      env {
        name  = "MYSQL_ROOT_PASSWORD"
        value = var.MYSQL_ROOT_PASSWORD
      }
      env {
        name  = "MYSQL_DATABASE"
        value = var.MYSQL_DATABASE
      }
    }
    volume {
      name = azurerm_storage_share.azure_storageshare.name
      storage_name = azurerm_container_app_environment_storage.container_app_storage_mount.name
      storage_type = "AzureFile"
    }
    max_replicas = 3
    min_replicas = 1
    cooldown_period_in_seconds  = 300
    polling_interval_in_seconds = 30
    tcp_scale_rule {
      name = "${var.prefix}-tcp-scale-rule"
      concurrent_requests = 10
    }
  }

  tags = {
    Environment = var.env
  }
}

resource "azurerm_container_app" "aca_bankapp" {
  name                         = "${var.prefix}-bankapp"

  container_app_environment_id = azurerm_container_app_environment.aca_environment.id
  resource_group_name          = azurerm_resource_group.aca_rg.name
  revision_mode                = "Multiple"

  secret {
    name  = "acr-password"
    value = var.PASSWORD_ACR
  }

  registry {
    server               = var.SERVER_ACR
    username             = var.USERNAME_ACR
    password_secret_name = "acr-password"
  }

  ingress {
    allow_insecure_connections = false
    external_enabled           = true
    target_port                = 8080
    traffic_weight {
      percentage      = 100
      label           = "current"
      latest_revision = true
    }
  }

  template {
    container {
      name   = "${var.prefix}-bankapp"
      image  = "${var.SERVER_ACR}/${var.REPO_NAME}:${var.TAG_NUMBER}"
      cpu    = 0.25
      memory = "0.5Gi"
      env {
        name  = "JDBC_URL"
        value = "jdbc:mysql://mysql-service:3306/bankappdb?allowPublicKeyRetrieval=true&useSSL=false&serverTimezone=UTC"
      }
      env {
        name  = "JDBC_PASS" 
        value = "Dexter@123"
      }
      env {
        name  = "JDBC_USER"
        value = "root"
      }      
    }
    max_replicas = 3
    min_replicas = 1
    cooldown_period_in_seconds  = 300
    polling_interval_in_seconds = 30
    http_scale_rule {
      name = "${var.prefix}-http-scale-rule"
      concurrent_requests = 100   ### The concurrent request to trigger scaling.
    }
  }

  tags = {
    Environment = var.env
  }

  depends_on = [azurerm_container_app.aca_mysql_app]

}

data "azurerm_dns_zone" "azure_dns_zone" {
  name                = "singhritesh85.com"
  resource_group_name = "dns-rosource-group"
}

resource "azurerm_dns_txt_record" "dns_txt_record" {
  name                = "asuid.www"
  resource_group_name = "dns-rosource-group"
  zone_name           = data.azurerm_dns_zone.azure_dns_zone.name
  ttl                 = 300

  record {
    value = azurerm_container_app.aca_bankapp.custom_domain_verification_id
  }
}

resource "azurerm_dns_cname_record" "example" {
  name                = "www"
  zone_name           = data.azurerm_dns_zone.azure_dns_zone.name
  resource_group_name = "dns-rosource-group"
  ttl                 = 300
  record              = azurerm_container_app.aca_bankapp.ingress[0].fqdn
}

resource "azurerm_container_app_custom_domain" "custom_domain" {
  name                                     = trimsuffix(trimprefix(azurerm_dns_txt_record.dns_txt_record.fqdn, "asuid."), ".")  ###"www.singhritesh85.com"
  container_app_id                         = azurerm_container_app.aca_bankapp.id
  container_app_environment_certificate_id = azurerm_container_app_environment_certificate.ssl_certificate.id
  certificate_binding_type                 = "SniEnabled"
}
