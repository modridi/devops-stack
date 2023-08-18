locals {
  backstage_values = {
    database = {
      username = base64encode("postgres")
      password = base64encode(random_password.backstage_db_password.result)
      host     = "postgres-svc"
    }
    backstage = {
      image = "ghcr.io/modridi/backstage"
      tag   = "0.1.0"
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
        host = "backstage.apps.${local.cluster_name}.${local.base_domain}"
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

resource "helm_release" "backstage" {
  name             = "backstage"
  chart            = "${path.module}/backstage-chart"
  namespace        = "backstage"
  create_namespace = true
  values           = [yamlencode(local.backstage_values)]
}
