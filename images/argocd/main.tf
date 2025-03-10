terraform {
  required_providers {
    apko = { source = "chainguard-dev/apko" }
  }
}

variable "target_repository" {
  description = "The docker repo into which the image and attestations should be published."
}

locals {
  components = toset(["argocd", "repo-server"])
}

module "latest" {
  for_each = local.components

  source = "../../tflib/publisher"

  name = basename(path.module)

  target_repository = (each.key == "argocd" ? var.target_repository : "${var.target_repository}-repo-server")
  config            = file("${path.module}/configs/latest.${each.key}.apko.yaml")
}

module "dev" { source = "../../tflib/dev-subvariant" }

module "latest-dev" {
  for_each = local.components

  source = "../../tflib/publisher"

  name = basename(path.module)

  target_repository = (each.key == "argocd" ? var.target_repository : "${var.target_repository}-repo-server")
  # Make the dev variant an explicit extension of the
  # locked original.
  config         = jsonencode(module.latest[each.key].config)
  extra_packages = module.dev.extra_packages
}

module "version-tags" {
  for_each = local.components

  source  = "../../tflib/version-tags"
  package = (each.key == "argocd" ? "argo-cd-2.8" : "argo-cd-2.8-repo-server")
  config  = module.latest[each.key].config
}

module "test-latest" {
  source  = "./tests"
  digests = { for k, v in module.latest : k => v.image_ref }
}

module "tagger" {
  for_each = local.components

  source = "../../tflib/tagger"

  depends_on = [
    module.test-latest,
  ]

  tags = merge(
    { for t in toset(concat(["latest"], module.version-tags[each.key].tag_list)) : t => module.latest[each.key].image_ref },
    { for t in toset(concat(["latest"], module.version-tags[each.key].tag_list)) : "${t}-dev" => module.latest-dev[each.key].image_ref },
  )
}
