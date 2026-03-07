📦 Git Branching & Release Strategy

This project follows a structured branching model to maintain stability, controlled releases, and safe hotfix handling.

🌳 Branch Structure
main

Production-ready code only

Always stable

Represents live Play Store build

Tagged with version numbers (e.g., v1.0.1)

dev

Active development branch

All features are merged here first

Integration testing happens here

feature/*

Created from dev

Used for developing new features

Merged back into dev after completion

Example:

feature/boost-listing
feature/supplier-order-edit

release/x.x.x

Created from dev when code is ready for QA

Only bug fixes allowed

No new features

Used for final testing before production

Example:

release/1.0.1
release/1.1.0


After approval:

Merged into main

Tagged with version

Merged back into dev

hotfix/*

Created from main

Used for urgent production fixes

Merged into:

main

dev

Active release branch (if applicable)

Example:

hotfix/payment-crash
hotfix/premium-calculation-error

🚀 Workflow
1️⃣ Feature Development
dev → feature/* → dev


Steps:

Create feature branch from dev

Develop and test

Merge back into dev

2️⃣ Creating a Release
dev → release/x.x.x → main


Steps:

Create release branch from dev

Perform QA & bug fixes

Merge into main

Tag version

Merge release back into dev

3️⃣ Production Hotfix
main → hotfix/* → main + dev (+ release if active)


Steps:

Create hotfix branch from main

Fix issue

Merge into main

Merge into dev

Tag new version if required

🏷 Versioning

We follow semantic versioning:

MAJOR.MINOR.PATCH


Example:

1.0.0 → Initial release

1.1.0 → New feature release

1.0.1 → Bug fix

⚠️ Rules

Never commit directly to main

Never develop directly on release/*

Never create hotfix from feature branch

Always regenerate pubspec.lock after dependency merge conflicts

Always tag production releases

📌 Example Release Flow
feature/boost → dev
dev stable → release/1.0.1
release tested → main
tag v1.0.1
merge release → dev