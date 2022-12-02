resource "azuread_application" "oauth2_apps" {
  display_name = format("oauth2-apps-dstack-%s", var.cluster_name)

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
      format("https://argocd.apps.%s.%s/auth/callback", var.cluster_name, var.dns_zone.name),
      format("https://grafana.apps.%s.%s/login/generic_oauth", var.cluster_name, var.dns_zone.name),
      format("https://prometheus.apps.%s.%s/oauth2/callback", var.cluster_name, var.dns_zone.name),
      format("https://alertmanager.apps.%s.%s/oauth2/callback", var.cluster_name, var.dns_zone.name),
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

resource "azuread_application_password" "oauth2_apps" {
  application_object_id = azuread_application.oauth2_apps.object_id
}
