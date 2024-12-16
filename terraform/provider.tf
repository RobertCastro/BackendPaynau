provider "aws" {
  region  = "us-east-1"

  default_tags {
    tags = {
      "Owner": "Robert Castro",
      "Source"= "https://github.com/RobertCastro",
      "Usage"= "FastAPI deployment on Lambda Functions"
    }
  }
}
