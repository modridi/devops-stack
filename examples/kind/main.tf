# Providers configuration

# These providers depend on the output of the respectives modules declared below.
# However, for clarity and ease of maintenance we grouped them all together in this section.

provider "kubernetes" {
  host                   = module.kind.parsed_kubeconfig.host
  client_certificate     = module.kind.parsed_kubeconfig.client_certificate
  client_key             = module.kind.parsed_kubeconfig.client_key
  cluster_ca_certificate = module.kind.parsed_kubeconfig.cluster_ca_certificate
}

provider "helm" {
  kubernetes {
    host                   = module.kind.parsed_kubeconfig.host
    client_certificate     = module.kind.parsed_kubeconfig.client_certificate
    client_key             = module.kind.parsed_kubeconfig.client_key
    cluster_ca_certificate = module.kind.parsed_kubeconfig.cluster_ca_certificate
  }
}

provider "argocd" {
  auth_token                  = module.argocd_bootstrap.argocd_auth_token
  port_forward_with_namespace = module.argocd_bootstrap.argocd_namespace
  insecure                    = true
  plain_text                  = true
  kubernetes {
    host                   = module.kind.parsed_kubeconfig.host
    client_certificate     = module.kind.parsed_kubeconfig.client_certificate
    client_key             = module.kind.parsed_kubeconfig.client_key
    cluster_ca_certificate = module.kind.parsed_kubeconfig.cluster_ca_certificate
  }
}

provider "keycloak" {
  client_id                = "admin-cli"
  username                 = module.keycloak.admin_credentials.username
  password                 = module.keycloak.admin_credentials.password
  url                      = "https://keycloak.apps.${local.cluster_name}.${local.base_domain}"
  tls_insecure_skip_verify = true
  initial_login            = false
}

###

# Module declarations and configuration

module "kind" {
  source = "git::https://github.com/camptocamp/devops-stack-module-cluster-kind.git?ref=v2.2.2"

  cluster_name       = local.cluster_name
  kubernetes_version = local.kubernetes_version
}

module "metallb" {
  source = "git::https://github.com/camptocamp/devops-stack-module-metallb.git?ref=v1.0.1"

  subnet = module.kind.kind_subnet
}

module "argocd_bootstrap" {
  source = "git::https://github.com/camptocamp/devops-stack-module-argocd.git//bootstrap?ref=v3.1.2"
}

module "traefik" {
  source = "git::https://github.com/camptocamp/devops-stack-module-traefik.git//kind?ref=v2.0.1"

  cluster_name = local.cluster_name

  # TODO fix: the base domain is defined later. Proposal: remove redirection from traefik module and add it in dependent modules.
  # For now random value is passed to base_domain. Redirections will not work before fix.
  base_domain = "placeholder.com"

  argocd_namespace = module.argocd_bootstrap.argocd_namespace

  enable_service_monitor = local.enable_service_monitor

  helm_values = [{
    traefik = {
      additionalArguments = [
        "--serversTransport.insecureSkipVerify=true",
        "--entrypoints.web.http.redirections.entryPoint.to=:443",
        "--entrypoints.web.http.redirections.entryPoint.scheme=https",
        "--entryPoints.postgresql.address=:5432/tcp"
      ]
    }
  }]

  dependency_ids = {
    argocd = module.argocd_bootstrap.id
  }
}

module "cert-manager" {
  source = "git::https://github.com/camptocamp/devops-stack-module-cert-manager.git//self-signed?ref=v5.0.1"

  argocd_namespace = module.argocd_bootstrap.argocd_namespace

  enable_service_monitor = local.enable_service_monitor

  dependency_ids = {
    argocd = module.argocd_bootstrap.id
  }
}

module "keycloak" {
  source = "git::https://github.com/camptocamp/devops-stack-module-keycloak?ref=v2.0.1"

  cluster_name     = local.cluster_name
  base_domain      = local.base_domain
  cluster_issuer   = local.cluster_issuer
  argocd_namespace = module.argocd_bootstrap.argocd_namespace

  dependency_ids = {
    traefik      = module.traefik.id
    cert-manager = module.cert-manager.id
  }
}

module "oidc" {
  source = "git::https://github.com/camptocamp/devops-stack-module-keycloak//oidc_bootstrap?ref=v2.0.1"

  cluster_name   = local.cluster_name
  base_domain    = local.base_domain
  cluster_issuer = local.cluster_issuer

  dependency_ids = {
    keycloak = module.keycloak.id
  }
}

module "minio" {
  source = "git::https://github.com/camptocamp/devops-stack-module-minio?ref=v2.0.1"

  cluster_name     = local.cluster_name
  base_domain      = local.base_domain
  cluster_issuer   = local.cluster_issuer
  argocd_namespace = module.argocd_bootstrap.argocd_namespace

  enable_service_monitor = local.enable_service_monitor

  config_minio = local.minio_config

  oidc = module.oidc.oidc

  dependency_ids = {
    traefik      = module.traefik.id
    cert-manager = module.cert-manager.id
    oidc         = module.oidc.id
  }
}

module "kube-prometheus-stack" {
  source = "git::https://github.com/camptocamp/devops-stack-module-kube-prometheus-stack//kind?ref=v6.0.1"

  cluster_name     = local.cluster_name
  base_domain      = local.base_domain
  cluster_issuer   = local.cluster_issuer
  argocd_namespace = module.argocd_bootstrap.argocd_namespace

  # metrics_storage = {
  #   bucket     = local.minio_config.buckets.1.name
  #   endpoint   = module.minio.endpoint
  #   access_key = local.minio_config.users.1.accessKey
  #   secret_key = local.minio_config.users.1.secretKey
  # }

  prometheus = {
    oidc = module.oidc.oidc
  }
  alertmanager = {
    oidc = module.oidc.oidc
  }
  grafana = {
    oidc = module.oidc.oidc
  }

  dependency_ids = {
    traefik      = module.traefik.id
    cert-manager = module.cert-manager.id
    minio        = module.minio.id
    oidc         = module.oidc.id
  }
}

module "argocd" {
  source = "git::https://github.com/camptocamp/devops-stack-module-argocd.git?ref=v3.1.2"

  base_domain              = local.base_domain
  cluster_name             = local.cluster_name
  cluster_issuer           = local.cluster_issuer
  server_secretkey         = module.argocd_bootstrap.argocd_server_secretkey
  accounts_pipeline_tokens = module.argocd_bootstrap.argocd_accounts_pipeline_tokens

  oidc = {
    name         = "OIDC"
    issuer       = module.oidc.oidc.issuer_url
    clientID     = module.oidc.oidc.client_id
    clientSecret = module.oidc.oidc.client_secret
    requestedIDTokenClaims = {
      groups = {
        essential = true
      }
    }
  }

  dependency_ids = {
    traefik               = module.traefik.id
    cert-manager          = module.cert-manager.id
    oidc                  = module.oidc.id
    kube-prometheus-stack = module.kube-prometheus-stack.id
  }

  # Temporary workaround: redirection to login page after OIDC login attempt
  helm_values = [{
    argo-cd = {
      server = {
        config = {
          "admin.enabled" = "true"
        }
      }
    }
  }]
}
