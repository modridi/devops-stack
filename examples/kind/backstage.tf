locals {
  backstage_values = {
    database = {
      username = base64encode("postgres")
      password = base64encode(random_password.backstage_db_password.result)
      host     = "postgres-svc"
    }
    backstage = {
      image = "ghcr.io/modridi/backstage"
      tag   = "0.5.0"
      imagePullSecret = base64encode(jsonencode(
        {
          "auths" = {
            "ghcr.io" = {
              "auth" = base64encode("${var.gh_username}:${var.gh_token}")
            }
          }
        }
      ))
      env = [
        {
          name  = "ARGOCD_AUTH_TOKEN"
          value = "argocd.token=${module.argocd_bootstrap.argocd_auth_token}"
        }
      ]
      ingress = {
        clusterIssuer = "ca-issuer"
        host          = "backstage.apps.${local.cluster_name}.${local.base_domain}"
      }
      config = <<-EOT
app:
  title: Scaffolded Backstage App
  baseUrl: https://backstage.apps.${local.cluster_name}.${local.base_domain}

organization:
  name: CampToCamp

backend:
  baseUrl: https://backstage.apps.${local.cluster_name}.${local.base_domain}
  listen:
    port: 7007
  csp:
    connect-src: ["'self'", 'http:', 'https:']
  cors:
    origin: https://backstage.apps.${local.cluster_name}.${local.base_domain}
    methods: [GET, HEAD, PATCH, POST, PUT, DELETE]
    credentials: true
  database:
    client: pg
    connection:
      host: postgres-svc
      port: 5432
      user: postgres
      password: ${random_password.backstage_db_password.result}

integrations:
  github:
    - host: github.com
      token: ${var.gh_token}

proxy:
  '/argocd/api':
    target: http://argocd-server.argocd/api/v1/
    headers:
      Cookie:
        $env: ARGOCD_AUTH_TOKEN
  '/grafana/api':
    target: http://kube-prometheus-stack-grafana.kube-prometheus-stack
    headers:
      Authorization: Bearer ${jsondecode(data.local_file.grafana_sa_token.content).key}
  '/prometheus/api':
    target: http://kube-prometheus-stack-prometheus.kube-prometheus-stack:9090/api/v1/

grafana:
  domain: https://grafana.apps.${local.cluster_name}.${local.base_domain}
  unifiedAlerting: false

techdocs:
  builder: 'local' # Alternatives - 'external'
  generator:
    runIn: 'docker' # Alternatives - 'local'
  publisher:
    type: 'local' # Alternatives - 'googleGcs' or 'awsS3'. Read documentation for using alternatives.

auth:
  providers: {}

scaffolder:

catalog:
  import:
    entityFilename: catalog-info.yaml
    pullRequestBranchName: backstage-integration
  rules:
    - allow: [Component, System, API, Resource, Location]
  locations:
    - type: url
      target: https://github.com/modridi/cloud-native-heroku/blob/demo/templates/01-hello-world/template.yaml
      rules:
        - allow: [Template]
    - type: url
      target: https://github.com/modridi/cloud-native-heroku/blob/demo/templates/02-image-and-chart/template.yaml
      rules:
        - allow: [Template]
    - type: url
      target: https://github.com/modridi/cloud-native-heroku/blob/demo/templates/03-argocd/template.yaml
      rules:
        - allow: [Template]
    - type: url
      target: https://github.com/modridi/cloud-native-heroku/blob/demo/templates/04-crossplane/template.yaml
      rules:
        - allow: [Template]
    - type: url
      target: https://github.com/modridi/demo-backstage/blob/main/examples/org.yaml
      rules:
        - allow: [User, Group]
      EOT
    }
  }
}

resource "random_password" "backstage_db_password" {
  length  = 32
  special = false
}

resource "helm_release" "crossplane" {
  name             = "crossplane"
  chart            = "crossplane"
  repository       = "https://charts.crossplane.io/stable"
  namespace        = "crossplane-system"
  create_namespace = true

  depends_on = [
    module.argocd
  ]
}

# https://medium.com/@danieljimgarcia/dont-use-the-terraform-kubernetes-manifest-resource-6c7ff4fe629a
provider "kubectl" {
  host                   = module.kind.parsed_kubeconfig.host
  client_certificate     = module.kind.parsed_kubeconfig.client_certificate
  client_key             = module.kind.parsed_kubeconfig.client_key
  cluster_ca_certificate = module.kind.parsed_kubeconfig.cluster_ca_certificate
}

resource "kubectl_manifest" "crossplane_aws_provider" {
  yaml_body = <<-EOF
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-aws-s3
spec:
  package: xpkg.upbound.io/upbound/provider-aws-s3:v0.38.0
  EOF

  depends_on = [
    helm_release.crossplane
  ]
}

resource "kubernetes_secret_v1" "aws_secret" {
  metadata {
    name      = "aws-secret"
    namespace = "crossplane-system"
  }

  data = {
    creds = <<EOT
[default]
aws_access_key_id = ${module.minio.minio_root_user_credentials.username}
aws_secret_access_key = ${module.minio.minio_root_user_credentials.password}
    EOT
  }

  depends_on = [
    kubectl_manifest.crossplane_aws_provider
  ]
}

resource "kubectl_manifest" "crossplane_aws_provider_config" {
  yaml_body = <<EOT
apiVersion: aws.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: aws-secret
      key: creds
  endpoint:
    services:
    - s3
    url:
      static: "http://${module.minio.endpoint}"
      type: Static
  s3_use_path_style: true
  skip_credentials_validation: true
  skip_metadata_api_check: true
  skip_requesting_account_id: true
  EOT

  depends_on = [
    kubernetes_secret_v1.aws_secret
  ]
}

resource "helm_release" "backstage" {
  name             = "backstage"
  chart            = "${path.module}/backstage-chart"
  namespace        = "backstage"
  create_namespace = true
  values           = [yamlencode(local.backstage_values)]

  depends_on = [
    helm_release.crossplane
  ]
}

# Ok, this sucks! Reason: couldn't create the service account with Grafana provider and didn't want to spend much time on this now.
# TODO: replace code between the following with something clean.

resource "null_resource" "create_grafana_backstage_service_account" {
  provisioner "local-exec" {
    command = <<EOT
      curl -k --header "Content-Type: application/json" \
        --request POST \
        --data '{"name":"backstage","role":"Admin"}' \
        https://admin:${module.kube-prometheus-stack.grafana_admin_password}@grafana.apps.${local.cluster_name}.${local.base_domain}/api/serviceaccounts > grafana_sa.json
    EOT
  }

  depends_on = [
    module.argocd
  ]

  lifecycle {
    ignore_changes = all
  }
}

data "local_file" "grafana_sa" {
  filename = "${path.module}/grafana_sa.json"

  depends_on = [
    null_resource.create_grafana_backstage_service_account
  ]
}

resource "null_resource" "create_grafana_backstage_service_account_token" {
  provisioner "local-exec" {
    command = <<EOT
      curl -k --header "Content-Type: application/json" \
        --request POST \
        --data '{"name":"backstage"}' \
        https://admin:${module.kube-prometheus-stack.grafana_admin_password}@grafana.apps.${local.cluster_name}.${local.base_domain}/api/serviceaccounts/${jsondecode(data.local_file.grafana_sa.content).id}/tokens > grafana_sa_token.json
    EOT
  }

  depends_on = [
    null_resource.create_grafana_backstage_service_account
  ]

  lifecycle {
    ignore_changes = all
  }
}

data "local_file" "grafana_sa_token" {
  filename = "${path.module}/grafana_sa_token.json"

  depends_on = [
    null_resource.create_grafana_backstage_service_account_token
  ]
}
