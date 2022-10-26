locals {
  oidc = {
    issuer_url              = format("https://login.microsoftonline.com/%s/v2.0", data.azurerm_client_config.current.tenant_id)
    oauth_url               = format("https://login.microsoftonline.com/%s/oauth2/authorize", data.azurerm_client_config.current.tenant_id)
    token_url               = format("https://login.microsoftonline.com/%s/oauth2/token", data.azurerm_client_config.current.tenant_id)
    api_url                 = format("https://graph.microsoft.com/oidc/userinfo")
    client_id               = azuread_application.application.application_id
    client_secret           = azuread_application_password.client_secret.value
    oauth2_proxy_extra_args = []
  }
}

resource "azuread_application" "application" {
  display_name = var.platform_name

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000"

    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"
      type = "Scope"
    }
  }

  optional_claims {
    access_token {
      additional_properties = []
      essential             = false
      name                  = "groups"
    }
    id_token {
      additional_properties = []
      essential             = false
      name                  = "groups"
    }
  }

  web {
    redirect_uris = [
      format("https://argocd.apps.%s.%s/auth/callback", var.cluster_name, azurerm_dns_zone.default.name),
      format("https://grafana.apps.%s.%s/login/generic_oauth", var.cluster_name, azurerm_dns_zone.default.name),
      format("https://prometheus.apps.%s.%s/oauth2/callback", var.cluster_name, azurerm_dns_zone.default.name),
      format("https://alertmanager.apps.%s.%s/oauth2/callback", var.cluster_name, azurerm_dns_zone.default.name),
    ]

    implicit_grant {
      access_token_issuance_enabled = false
      id_token_issuance_enabled     = false
    }
  }

  app_role {
    allowed_member_types = ["User"]
    description          = "ArgoCD Admins"
    display_name         = "ArgoCD Administrator"
    enabled              = true
    id                   = random_uuid.argocd_app_role_admin.result
    value                = "argocd-admin"
  }

  app_role {
    allowed_member_types = ["User"]
    description          = "ArgoCD Users"
    display_name         = "ArgoCD Users"
    enabled              = true
    id                   = random_uuid.argocd_app_role_user.result
    value                = "argocd-user"
  }

  group_membership_claims = ["ApplicationGroup"]
}

resource "random_uuid" "argocd_app_role_admin" {
}

resource "random_uuid" "argocd_app_role_user" {
}

resource "azuread_application_password" "client_secret" {
  application_object_id = azuread_application.application.object_id
}
