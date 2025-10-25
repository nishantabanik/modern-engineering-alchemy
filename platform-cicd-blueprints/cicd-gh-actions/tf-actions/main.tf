# Google reources

resource "google_storage_bucket" "bucket" {
  project  = "terraform-dojo-475414"
  name     = "tf-actions-bucket-012"
  location = "EU"
}
