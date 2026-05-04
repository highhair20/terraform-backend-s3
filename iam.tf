# ---------------------------------------------------------------------------
# GitHub Actions OIDC Identity Provider
# Allows GitHub Actions workflows to assume per-project IAM roles without
# long-lived access keys. Trust relationships are configured per project
# using new-project.sh.
# ---------------------------------------------------------------------------
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # Current thumbprint for token.actions.githubusercontent.com
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}
