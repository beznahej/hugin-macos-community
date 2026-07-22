# Security Policy

Do not disclose a vulnerability publicly before maintainers have had a reasonable opportunity to investigate it.

Until a dedicated security contact is established, use GitHub's private vulnerability-reporting feature when enabled. Otherwise, open a minimal issue requesting a private contact channel without including exploit details.

Release engineering must never store Apple signing certificates, private keys, notarization credentials or passwords in the repository. GitHub Actions should use encrypted secrets and short-lived credentials where supported.
