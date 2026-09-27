# Contributing

Thank you for improving `aws.modules.iam`. Read this whole guide before opening a pull request: this module has one rule that overrides everything below it.

## The one rule

This module creates the GitHub Actions OIDC provider and the roles that authenticate every `terraform apply` in this platform, including applies of this module itself. Every resource carries `lifecycle { prevent_destroy = true }`, and there is no console-change escape hatch if a bad change ships (ADR 0022). Because of that:

**A pull request must not rename, move, or re-scope any resource's real-world identity** — a role name, a role path, a policy name, a trust-policy condition, or a decoded policy document — for any input `sandbox-delivery`'s real `terraform.tfvars` currently sets. `tests/golden_master.tftest.hcl` is built from those real inputs and enforces this mechanically. If your change makes that test fail, your change is not ready, no matter how good the underlying idea is: revert it and record it under "Deferred to v2" in [docs/DESIGN.md](docs/DESIGN.md) instead, describing what a live migration would need. This is the one module in this platform where "I found a real improvement but didn't make it" is often the correct pull request.

Read [docs/DESIGN.md](docs/DESIGN.md) in full, especially "Deferred to v2", before writing any code: it lists the changes that look easy and are not.

## Development setup

The module targets Terraform `>= 1.7.0, < 2.0.0` and is developed against 1.7.5, the version the consuming platform pins. Install the toolchain:

| Tool | Purpose | Install |
| --- | --- | --- |
| [tfenv](https://github.com/tfutils/tfenv) | Pin the Terraform version | `tfenv install 1.7.5 && tfenv use 1.7.5` |
| [tflint](https://github.com/terraform-linters/tflint) | Lint with the Terraform and AWS rulesets configured in `.tflint.hcl` | `brew install tflint && tflint --init` |
| [terraform-docs](https://terraform-docs.io) v0.20.0 | Generate the inputs and outputs tables in the README. Pinned to the version bundled by the CI docs action; newer releases change table formatting and fail the drift check (`make docs` refuses other versions). | Download the v0.20.0 binary from the [releases page](https://github.com/terraform-docs/terraform-docs/releases/tag/v0.20.0) |
| [checkov](https://www.checkov.io) | Static security policy | `pip install checkov` |
| [trivy](https://trivy.dev) | Misconfiguration scanning | `brew install trivy` |
| [pre-commit](https://pre-commit.com) | Run the gate on every commit | `pip install pre-commit && pre-commit install` |

Clone, initialise without a backend, and run the gate once to confirm the setup:

```sh
terraform init -backend=false -input=false
make check
```

## No integration suite, ever, without review first

Unlike this platform's other modules, `tests/integration/` does not exist here and must not be added casually. This module has no safe way to create a disposable copy of itself: a second OIDC provider or a second delivery role is exactly the uncontrolled IAM sprawl it exists to prevent, and `prevent_destroy` means a mistaken apply cannot be cleaned up by `terraform destroy` either. If you believe a narrow, genuinely safe integration check is possible, propose it in your pull request description and do not implement it without that proposal being reviewed and accepted first.

## The local gate

`make check` is the default target and the same gate CI runs. It stops at the first failing target and must pass before you open a pull request.

| Target | What it runs |
| --- | --- |
| `make fmt` | `terraform fmt -check -recursive -diff` from the repository root. `make fmt-fix` rewrites the files instead. |
| `make validate` | `make init` (`terraform init -backend=false`) followed by `terraform validate` in the root. |
| `make lint` | `tflint --init` and then `tflint` with the root `.tflint.hcl`: documented and typed variables, documented outputs, snake_case naming, no unused declarations, pinned required versions and providers. |
| `make test` | `terraform test` in the root. No credentials are needed, ever. |
| `make lock` | Refresh the committed root `.terraform.lock.hcl` with hashes for linux and macOS on amd64 and arm64 after changing the provider constraint. |
| `make docs` | `terraform-docs -c .terraform-docs.yml` in the root, regenerating the tables between the `BEGIN_TF_DOCS` and `END_TF_DOCS` markers. Run it after touching any variable or output. |
| `make docs-check` | The same in `--output-check` mode: fails when the README is out of date. This is the variant `make check` and CI run. |
| `make security` | `checkov -d . --framework terraform`, and `trivy config --severity HIGH,CRITICAL` when trivy is on the PATH. |
| `make check` | `fmt`, `validate`, `lint`, `test`, `docs-check`, `security`, in that order. |

## Test-first workflow, with the golden master first

Every behaviour in this module is pinned by a test before it is implemented, and for this module the golden master comes first:

1. Before writing any code, confirm `tests/golden_master.tftest.hcl` currently passes on `main`: `terraform test -filter=tests/golden_master.tftest.hcl`.
2. Write your change.
3. Run the golden master again. If it fails, your change altered a real identity; see "The one rule" above.
4. Write or extend a generic-input test (`tests/oidc.tftest.hcl`, `tests/validation.tftest.hcl`, `tests/preconditions.tftest.hcl`, `tests/checks.tftest.hcl`, or `tests/policy_shape.tftest.hcl`, whichever concern you touched) so the behaviour is proven for any valid input, not only `sandbox-delivery`'s.
5. Run `make test`.

Other rules that apply to every test file:

- Each file starts with `mock_provider "aws" {}`, an `override_data` block pinning `data.aws_partition.current` to `"aws"`, and a `variables` block holding a valid baseline; each `run` overrides only what it exercises.
- Use `command = plan`. Nothing here talks to AWS, so tests run in seconds and in CI without credentials. Do not add a `command = apply` run: every resource's `prevent_destroy` makes `terraform test`'s own teardown fail after an apply (confirmed directly; see the pull request history for this release). `aws.modules.state`'s `tests/wired/` and `scripts/lift-destroy-guards.sh` are the only precedent for testing an apply-time property in a `prevent_destroy` module in this platform, and adopting that pattern here needs its own review.
- Validations and preconditions are tested with `expect_failures`. Point it at the object that carries the check: `[var.role_prefix]` for a variable validation, `[aws_iam_role.github_actions]` for a precondition. A run with `expect_failures` passes only if exactly those objects fail; add a positive run alongside so the happy path is covered too, and prove every new validation still accepts `sandbox-delivery`'s real inputs unmodified.
- `||` and `&&` do not short-circuit in Terraform 1.7. Guard a null-dependent expression with a conditional instead: `var.x == null ? true : var.x.field > 0`.
- Comparing `keys()` of a `for_each` resource against a list literal with `==` can spuriously evaluate `false` even when both sides are identical under `jsonencode()` (observed and documented in `tests/oidc.tftest.hcl`). Compare `for_each` key sets with `toset(...) == toset([...])` instead, which is also the semantically correct comparison since a key set is unordered.
- Keep assertion `error_message` text a statement of the guaranteed behaviour, prefixed `GOLDEN MASTER:` or `GOLDEN INVARIANT:` when the assertion is one this module's whole purpose depends on. It becomes the documentation of the contract when a test fails.

## Where to add a feature

The module has no submodules; concerns are split by file, and each file has one reason to change.

| Concern | Lives in |
| --- | --- |
| The OIDC provider or the six fixed roles | `oidc.tf`, tested in `tests/oidc.tftest.hcl` and pinned in `tests/golden_master.tftest.hcl`. |
| Opt-in image-publisher roles | `image_publishers.tf`. |
| A delivery policy's `aws_iam_policy` resource (not its document) | `delivery_policies.tf`. |
| A policy's actual JSON document | `policies.tf`. Any change here needs a policy-document diff proof the same way `tests/golden_master.tftest.hcl` proves it, per "The one rule" above. |
| Role-to-policy wiring | `attachments.tf`. This is the only file that grants permission. |
| Shared names, ARNs, and the attachment map | `locals.tf`. |
| Advisory, non-blocking warnings | `checks.tf`, tested in `tests/checks.tftest.hcl`. |
| A structural, input-independent policy invariant | `tests/policy_shape.tftest.hcl`. |
| Outputs | `outputs.tf`; every output has a description. |

Rules that apply everywhere: no data sources beyond `data.aws_partition.current`, every variable has a description, a type, and a validation where a wrong value would otherwise fail at apply time, every output has a description, and every resource keeps `lifecycle { prevent_destroy = true }` — `terraform test` cannot see a `lifecycle` block, so a reviewer confirms this by reading the diff directly.

## Commits

Use [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/). The scope is the file or concern the change touches.

```text
feat(checks): warn when an image publisher targets an unowned repository
fix(preconditions): correct the publisher role name length boundary
docs: explain the sandbox-sandbox naming stutter in DESIGN.md
test(golden-master): add the landing_zone role's trust condition
```

A change to this module is breaking only when a live migration is unavoidable and reviewed as such; see "The one rule". There is no `feat!` in this module's history yet, and there should not be one without a deliberate, coordinated migration plan reviewed alongside it.

## Pull request checklist

- [ ] `tests/golden_master.tftest.hcl` passes, unmodified in its assertions (only new `run` blocks may be added, for a resource this PR adds; no existing assertion's expected value changes).
- [ ] `make check` passes locally.
- [ ] New behaviour has a test; changed validations have both a passing and an `expect_failures` run.
- [ ] Variables and outputs have descriptions; `make docs` regenerated the README tables.
- [ ] `CHANGELOG.md` has an entry under `## [Unreleased]` in the right category.
- [ ] Any deferred, real improvement is recorded under "Deferred to v2" in `docs/DESIGN.md`, not implemented.
- [ ] No data sources added beyond `data.aws_partition.current`, no hard-coded account or region, no new defaults that weaken security, and no new integration suite without prior review.

## Release process

Releases are cut by maintainers.

1. Move the `## [Unreleased]` entries in `CHANGELOG.md` under a new `## [X.Y.Z] - YYYY-MM-DD` heading, add its compare link, and merge that change to `main`.
2. Create a signed annotated tag on the merge commit. The signing key must be registered with GitHub so the tag shows as Verified:

   ```sh
   git tag -s vX.Y.Z -m "aws.modules.iam vX.Y.Z"
   git push origin vX.Y.Z
   ```

3. Dispatch the `module-release` workflow (`.github/workflows/module-release.yml`) from the tag with `release_tag = vX.Y.Z`: `gh workflow run module-release.yml --ref vX.Y.Z -f release_tag=vX.Y.Z`. Never dispatch it from `main`.
4. Announce the release with the commit SHA. Consumers pin that SHA, not the tag:

   ```hcl
   source = "git::https://github.com/hatan4ik/aws.modules.iam.git?ref=<commit-sha>" # vX.Y.Z
   ```

5. Tell `sandbox-delivery`'s maintainers the release is available and hand them `docs/UPGRADE-<major>.md` if this was a major release. This module has exactly one consumer; do not consider a release "shipped" until that consumer has planned against it and confirmed **no changes**.

Tags are never moved or deleted once published. A bad release is followed by a new patch release, never a force-push or a tag rewrite.
