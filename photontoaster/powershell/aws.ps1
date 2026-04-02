# PhotonToaster PowerShell AWS helpers

function global:pt-aws-login {
  if (Get-Command aws -ErrorAction SilentlyContinue) {
    Write-Host "AWS CLI found. Run your SSO/login command as needed."
  } else {
    Write-Host "AWS CLI not found."
  }
}
