terraform {                                        # top-lvl block where to define settings related to tf behavior + backend config
  backend "s3" {                                   # state file stored in s3 bucket
    bucket         = "assou-my-tf-website-state"   # name of bucket where state is stored
    key            = "global/s3/terraform.tfstate" # path within s3 bucket where state is stored
    region         = "ca-central-1"
    dynamodb_table = "my-db-web-table" # table used to lock state file during operation, to avoid conflicts
  }
}
