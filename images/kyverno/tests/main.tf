terraform {
  required_providers {
    oci  = { source = "chainguard-dev/oci" }
    helm = { source = "hashicorp/helm" }
  }
}

variable "digests" {
  description = "The image digests to run tests over."
  type = object({
    admission  = string
    background = string
    cleanup    = string
    cli        = string
    init       = string
    reports    = string
  })
}

data "oci_string" "ref" {
  for_each = var.digests
  input    = each.value
}

data "oci_exec_test" "help" {
  for_each = var.digests
  digest   = each.value
  script   = "docker run --rm $IMAGE_NAME --help"
}

resource "helm_release" "kyverno" {
  name             = "kyverno"
  namespace        = "kyverno"
  repository       = "https://kyverno.github.io/kyverno"
  chart            = "kyverno"
  create_namespace = true

  values = [jsonencode({
    admissionController = {
      container = {
        image = {
          registry   = data.oci_string.ref["admission"].registry
          repository = data.oci_string.ref["admission"].repo
          tag        = data.oci_string.ref["admission"].pseudo_tag
        }
      }
      initContainer = {
        image = {
          registry   = data.oci_string.ref["init"].registry
          repository = data.oci_string.ref["init"].repo
          tag        = data.oci_string.ref["init"].pseudo_tag
        }
      }
    }
    backgroundController = {
      container = {
        image = {
          registry = data.oci_string.ref["background"].registry
          registry = data.oci_string.ref["background"].repo
          tag      = data.oci_string.ref["background"].pseudo_tag
        }
      }
    }
    cleanupController = {
      container = {
        image = {
          registry = data.oci_string.ref["cleanup"].registry
          registry = data.oci_string.ref["cleanup"].repo
          tag      = data.oci_string.ref["cleanup"].pseudo_tag
        }
      }
    }
    reportsController = {
      container = {
        image = {
          registry = data.oci_string.ref["reports"].registry
          registry = data.oci_string.ref["reports"].repo
          tag      = data.oci_string.ref["reports"].pseudo_tag
        }
      }
    }
  })]
}
