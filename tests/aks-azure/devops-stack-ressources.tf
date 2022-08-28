# Resource Group

resource "azurerm_resource_group" "devops_stack_modules" {
  name     = "devops-stack-modules"
  location = "France Central"
}

# OIDC
resource "azuread_application" "oauth2_apps" {
  display_name = "oauth2-apps-is-internal-dev"

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
      format("https://argocd.apps.blue.%s/auth/callback", azurerm_dns_zone.is_internal.name),
      format("https://thanos-query.apps.blue.%s/oauth2/callback", azurerm_dns_zone.is_internal.name),
      format("https://thanos-bucketweb.apps.blue.%s/oauth2/callback", azurerm_dns_zone.is_internal.name),
      format("https://grafana.apps.blue.%s/login/generic_oauth", azurerm_dns_zone.is_internal.name),
      format("https://prometheus.apps.blue.%s/oauth2/callback", azurerm_dns_zone.is_internal.name),
      format("https://alertmanager.apps.blue.%s/oauth2/callback", azurerm_dns_zone.is_internal.name),
      format("https://traefik.apps.blue.%s/_oauth", azurerm_dns_zone.is_internal.name),
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

  owners = [
    "e54fbd6e-cff9-4ee7-a43e-96e885572e34",
  ]

  group_membership_claims = ["ApplicationGroup"]
}

resource "random_uuid" "argocd_app_role_admin" {
}

resource "random_uuid" "argocd_app_role_user" {
}

resource "azuread_application_password" "oauth2_apps" {
  application_object_id = azuread_application.oauth2_apps.object_id
}
