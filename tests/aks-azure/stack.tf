# module "cluster" {
#   source  = "Azure/aks/azurerm"
#   version = "6.2.0"

#   kubernetes_version   = 1.24
#   orchestrator_version = 1.24
#   prefix               = var.cluster_name

#   vnet_subnet_id = azurerm_subnet.default.id

#   resource_group_name               = azurerm_resource_group.default.name
#   azure_policy_enabled              = true
#   network_plugin                    = "azure"
#   private_cluster_enabled           = false
#   rbac_aad_managed                  = true
#   role_based_access_control_enabled = true
#   log_analytics_workspace_enabled   = false
#   sku_tier                          = "Free"
#   agents_pool_name                  = "default"
#   agents_labels                     = { "devops-stack/nodepool" : "default" }
#   agents_count                      = 1
#   agents_size                       = "Standard_D4s_v3"
#   agents_max_pods                   = 150
#   os_disk_size_gb                   = 128
# }

# provider "helm" {
#   kubernetes {
#     host                   = module.cluster.admin_host
#     cluster_ca_certificate = base64decode(module.cluster.admin_cluster_ca_certificate)
#     client_key             = base64decode(module.cluster.admin_client_key)
#     client_certificate     = base64decode(module.cluster.admin_client_certificate)
#     username               = module.cluster.admin_username
#     password               = module.cluster.admin_password
#   }
# }

# module "argocd" {
#   source         = "git::https://github.com/camptocamp/devops-stack-module-argocd.git//bootstrap?ref=v1.0.0-alpha.1"
#   cluster_name   = var.cluster_name
#   base_domain    = var.dns_zone.name
#   cluster_issuer = "letsencrypt-staging"
# }

# provider "argocd" {
#   server_addr                 = "127.0.0.1:8080"
#   auth_token                  = module.argocd.argocd_auth_token
#   insecure                    = true
#   plain_text                  = true
#   port_forward                = true
#   port_forward_with_namespace = module.argocd.argocd_namespace

#   kubernetes {
#     host                   = module.cluster.admin_host
#     cluster_ca_certificate = base64decode(module.cluster.admin_cluster_ca_certificate)
#     client_key             = base64decode(module.cluster.admin_client_key)
#     client_certificate     = base64decode(module.cluster.admin_client_certificate)
#   }
# }

# module "ingress" {
#   source = "git::https://github.com/camptocamp/devops-stack-module-traefik.git//aks?ref=main"

#   cluster_name                 = var.cluster_name
#   argocd_namespace             = module.argocd.argocd_namespace
#   base_domain                  = var.dns_zone.name
#   node_resource_group_name     = azurerm_resource_group.default.name
#   dns_zone_resource_group_name = var.dns_zone.resource_group
# }

# module "aad-pod-identity" {
#   source = "git::https://github.com/camptocamp/devops-stack-module-aad-pod-identity.git?ref=main"

#   cluster_name             = var.cluster_name
#   argocd_namespace         = module.argocd.argocd_namespace
#   node_resource_group_name = module.cluster.node_resource_group
#   base_domain              = var.dns_zone.name
#   cluster_managed_identity = lookup(module.cluster.kubelet_identity[0], "object_id")

#   azure_identities = []
# }

# module "cert-manager" {
#   source = "git::https://github.com/camptocamp/devops-stack-module-cert-manager.git//aks?ref=main"

#   cluster_name                 = var.cluster_name
#   argocd_namespace             = module.argocd.argocd_namespace
#   node_resource_group_name     = module.cluster.node_resource_group
#   dns_zone_resource_group_name = var.dns_zone.resource_group
#   base_domain                  = var.dns_zone.name

#   depends_on = [module.aad-pod-identity]
# }

# module "monitoring" {
#   source = "git::https://github.com/camptocamp/devops-stack-module-kube-prometheus-stack.git//aks?ref=azure-missing"

#   node_resource_group_name = module.cluster.node_resource_group
#   cluster_name             = var.cluster_name
#   argocd_namespace         = module.argocd.argocd_namespace
#   base_domain              = var.dns_zone.name
#   cluster_issuer           = "letsencrypt-staging"

#   alertmanager = {
#     oidc = local.oidc
#   }
#   prometheus = {
#     oidc = local.oidc
#   }
# }

# module "argocd_final" {
#   source = "git::https://github.com/camptocamp/devops-stack-module-argocd.git?ref=v1.0.0-alpha.1"

#   bootstrap_values = module.argocd.bootstrap_values
#   argocd_namespace = module.argocd.argocd_namespace

#   oidc = {
#     name         = "OIDC"
#     issuer       = local.oidc.issuer_url
#     clientID     = local.oidc.client_id
#     clientSecret = local.oidc.client_secret
#     requestedIDTokenClaims = {
#       groups = {
#         essential = true
#       }
#     }
#     requestedScopes = [
#       "openid", "profile", "email"
#     ]
#   }
# }

# module "loki-stack" {
#   source = "git::https://github.com/camptocamp/devops-stack-module-loki-stack.git//aks?ref=bucket_credentials"

#   argocd_namespace = module.argocd.argocd_namespace

#   logs_storage = {
#     container_name       = azurerm_storage_container.logs.name
#     storage_account_name = azurerm_storage_account.logs.name
#     storage_account_key  = azurerm_storage_account.logs.primary_access_key
#   }
# }

# module "grafana" {
#   source = "git::https://github.com/camptocamp/devops-stack-module-grafana.git"

#   base_domain      = var.dns_zone.name
#   cluster_name     = var.cluster_name
#   argocd_namespace = module.argocd.argocd_namespace
#   cluster_issuer   = "letsencrypt-staging"

#   grafana = {
#     oidc = local.oidc
#   }
# }

# module "thanos" {}

# module "csi-secrets-store-provider-azure" {
#   source = "git::https://github.com/camptocamp/devops-stack-module-csi-secrets-store-provider-azure.git"

#   argocd_namespace    = module.argocd.argocd_namespace
# }
