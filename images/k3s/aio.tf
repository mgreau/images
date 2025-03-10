module "latest-aio" {
  source = "../../tflib/publisher"

  name              = basename(path.module)
  target_repository = "${var.target_repository}-allinone"
  config            = file("${path.module}/configs/latest.aio.apko.yaml")
}

module "latest-aio-dev" {
  source = "../../tflib/publisher"

  name              = basename(path.module)
  target_repository = "${var.target_repository}-allinone"
  config            = jsonencode(module.latest-aio.config)
  extra_packages    = module.dev.extra_packages
}

module "version-tags-aio" {
  source = "../../tflib/version-tags"
  # Use the primary package as the version tagger since `k3s-images` only includes image bits
  package = "k3s"
  config  = module.latest.config
}
