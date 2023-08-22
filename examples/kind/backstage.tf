locals {
  backstage_values = {
    database = {
      username = base64encode("postgres")
      password = base64encode(random_password.backstage_db_password.result)
      host     = "postgres-svc"
    }
    backstage = {
      image = "ghcr.io/modridi/backstage"
      tag   = "0.2.0"
      imagePullSecret = base64encode(jsonencode(
        {
          "auths" = {
            "ghcr.io" = {
              "auth" = base64encode("${var.gh_username}:${var.gh_token}")
            }
          }
        }
      ))
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

resource "kubernetes_manifest" "crossplane_aws_provider" {
  manifest = yamldecode(
    <<EOT
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-aws-s3
spec:
  package: xpkg.upbound.io/upbound/provider-aws-s3:v0.38.0
    EOT
  )

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
    kubernetes_manifest.crossplane_aws_provider
  ]
}

resource "kubernetes_manifest" "crossplane_aws_provider_config" {
  manifest = yamldecode(
    <<EOT
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
  )

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
