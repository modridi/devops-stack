# module "cluster" {
#   source              = "git::https://github.com/camptocamp/devops-stack.git//modules/aks/azure?ref=v1"
#   cluster_name        = var.platform_name
#   kubernetes_version  = "1.23.12"
#   base_domain         = azurerm_dns_zone.default.name
#   vnet_subnet_id      = azurerm_subnet.default.id
#   resource_group_name = azurerm_resource_group.default.name
#   public_ssh_key      = tls_private_key.node_ssh_key.public_key_openssh
#   agents_max_pods     = 250
#   agents_size         = "Standard_D4s_v3"
#   agents_count        = 2

#   depends_on = [
#     tls_private_key.node_ssh_key
#   ]
# }

# provider "helm" {
#   kubernetes {
#     host                   = module.cluster.kube_admin_config.host
#     cluster_ca_certificate = module.cluster.kube_admin_config.cluster_ca_certificate
#     client_key             = module.cluster.kube_admin_config.client_key
#     client_certificate     = module.cluster.kube_admin_config.client_certificate
#     username               = module.cluster.kube_admin_config.username
#     password               = module.cluster.kube_admin_config.password
#   }
# }

# module "argocd" {
#   source         = "git::https://github.com/camptocamp/devops-stack-module-argocd.git//bootstrap"
#   cluster_name   = var.cluster_name
#   base_domain    = module.cluster.base_domain
#   oidc           = local.oidc
#   cluster_issuer = "letsencrypt-prod"
# }

# provider "argocd" {
#   server_addr                 = "127.0.0.1:8080"
#   auth_token                  = module.argocd.argocd_auth_token
#   insecure                    = true
#   plain_text                  = true
#   port_forward                = true
#   port_forward_with_namespace = module.argocd.argocd_namespace

#   kubernetes {
#     host                   = module.cluster.kube_admin_config.host
#     cluster_ca_certificate = module.cluster.kube_admin_config.cluster_ca_certificate
#     client_key             = module.cluster.kube_admin_config.client_key
#     client_certificate     = module.cluster.kube_admin_config.client_certificate
#   }
# }

# module "ingress" {
#   source = "git::https://github.com/camptocamp/devops-stack-module-traefik.git//aks"

#   cluster_name        = var.cluster_name
#   argocd_namespace    = module.argocd.argocd_namespace
#   base_domain         = module.cluster.base_domain
#   resource_group_name = azurerm_resource_group.default.name

#   helm_values = [
#     {
#       traefik = {
#         ressources = {
#           limits = {
#             memory = "1Gi"
#           },
#         }

#       }
#     }
#   ]
# }

# module "aad-pod-identity" {
#   source = "git::https://github.com/camptocamp/devops-stack-module-aad-pod-identity.git"

#   cluster_name        = var.cluster_name
#   argocd_namespace    = module.argocd.argocd_namespace
#   resource_group_name = azurerm_resource_group.default.name
#   base_domain         = module.cluster.base_domain

#   azure_identities = []
# }

# module "cert-manager" {
#   source = "git::https://github.com/camptocamp/devops-stack-module-cert-manager.git//aks"

#   cluster_name        = var.cluster_name
#   argocd_namespace    = module.argocd.argocd_namespace
#   resource_group_name = azurerm_resource_group.default.name
#   base_domain         = module.cluster.base_domain

#   node_resource_group_name = module.cluster.node_resource_group

#   depends_on = [module.aad-pod-identity]
# }

# module "monitoring" {
#   source = "git::https://github.com/camptocamp/devops-stack-module-kube-prometheus-stack.git//aks"

#   resource_group_name      = azurerm_resource_group.default.name
#   node_resource_group_name = module.cluster.node_resource_group
#   cluster_name             = var.cluster_name
#   oidc                     = local.oidc
#   argocd_namespace         = module.argocd.argocd_namespace
#   base_domain              = module.cluster.base_domain
#   cluster_issuer           = "letsencrypt-prod"
#   metrics_archives         = {}
# }

# module "loki-stack" {
#   source = "git::https://github.com/camptocamp/devops-stack-module-loki-stack.git//aks"

#   resource_group_name = azurerm_resource_group.default.name
#   cluster_name        = var.cluster_name
#   argocd_namespace    = module.argocd.argocd_namespace
#   base_domain         = module.cluster.base_domain

#   depends_on = [module.monitoring]
# }

# module "csi-secrets-store-provider-azure" {
#   source = "git::https://github.com/camptocamp/devops-stack-module-csi-secrets-store-provider-azure.git"

#   argocd_namespace    = module.argocd.argocd_namespace
# }

# module "argocd_second" {
#   source = "git::https://github.com/camptocamp/devops-stack-module-argocd.git"

#   bootstrap_values = module.argocd.bootstrap_values
#   argocd_namespace = module.argocd.argocd_namespace

#   depends_on = [module.cert-manager, module.monitoring]
# }
