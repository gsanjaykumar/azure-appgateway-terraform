# ─── App Service Plan ─────────────────────────────────────────────────────────

resource "azurerm_service_plan" "plan" {
  name                = var.app_service_plan_name
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = var.app_service_plan_sku
  tags                = var.tags
}

# ─── App Services ─────────────────────────────────────────────────────────────

resource "azurerm_linux_web_app" "apps" {
  count               = length(var.app_service_names)
  name                = var.app_service_names[count.index]
  location            = var.location
  resource_group_name = var.resource_group_name
  service_plan_id     = azurerm_service_plan.plan.id
  https_only          = false # App GW communicates over HTTP internally
  tags                = var.tags

  site_config {
    always_on         = true
    health_check_path = "/health"

    application_stack {
      python_version = var.python_version
    }

    # CORS — allow App Gateway and Front Door
    cors {
      allowed_origins     = ["*"]
      support_credentials = false
    }

    # Access restrictions — only allow traffic from App Gateway subnet
    # This is what makes the architecture truly secure
    # Direct access to *.azurewebsites.net will return 403 Forbidden
    ip_restriction {
      name        = "Allow-AppGateway-Subnet"
      action      = "Allow"
      priority    = 100
      service_tag = "VirtualNetwork"
    }

    ip_restriction {
      name       = "Deny-All-Public"
      action     = "Deny"
      priority   = 200
      ip_address = "0.0.0.0/0"
    }

    scm_ip_restriction {
      name        = "Allow-SCM-VirtualNetwork"
      action      = "Allow"
      priority    = 100
      service_tag = "VirtualNetwork"
    }

    scm_ip_restriction {
      name       = "Allow-SCM-Azure"
      action     = "Allow"
      priority   = 110
      service_tag = "AzureCloud"
    }
  }

  app_settings = merge(var.app_settings_base, {
    APP_SERVICE_NAME                  = var.app_service_names[count.index]
    REGION                            = var.location
    INSTANCE_NUMBER                   = tostring(count.index + 1)
    NETWORK_MODE                      = "AppGateway"
    WEBSITES_PORT                     = "8000"
    SCM_DO_BUILD_DURING_DEPLOYMENT    = "true"
    ENABLE_ORYX_BUILD                 = "true"
  })

  logs {
    application_logs {
      file_system_level = "Information"
    }
    http_logs {
      file_system {
        retention_in_days = 7
        retention_in_mb   = 35
      }
    }
    detailed_error_messages = true
    failed_request_tracing  = true
  }

  identity {
    type = "SystemAssigned"
  }
}

# ─── VNet Integration ─────────────────────────────────────────────────────────
# Connects App Services to the VNet for outbound traffic
# Allows App Services to communicate with resources in the VNet

resource "azurerm_app_service_virtual_network_swift_connection" "vnet_integration" {
  count          = length(var.app_service_names)
  app_service_id = azurerm_linux_web_app.apps[count.index].id
  subnet_id      = var.appservice_subnet_id

  depends_on = [azurerm_linux_web_app.apps]
}

# ─── Wait for App Services to be fully ready ─────────────────────────────────
# Lesson learned from Module 1: Race condition between VNet integration save
# and ZIP deploy causes startup cancellation. 30s sleep prevents this.

resource "time_sleep" "wait_for_app_services" {
  create_duration = "30s"
  depends_on      = [azurerm_app_service_virtual_network_swift_connection.vnet_integration]
}

# ─── Deploy Flask application ─────────────────────────────────────────────────

resource "null_resource" "deploy_app" {
  count = length(var.app_service_names)

  triggers = {
    app_service_id = azurerm_linux_web_app.apps[count.index].id
    app_zip_hash   = filemd5(var.app_zip_path)
  }

  provisioner "local-exec" {
    # Windows CMD compatible — no backslash line continuation
    # --async true prevents 504 timeout on slow deployments
    command     = "az webapp deploy --resource-group ${var.resource_group_name} --name ${var.app_service_names[count.index]} --src-path ${var.app_zip_path} --type zip --async true"
    interpreter = ["cmd", "/C"]
  }

  depends_on = [time_sleep.wait_for_app_services]
}
