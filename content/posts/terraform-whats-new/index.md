---
title: "What's New in Terraform: Every Release Since 1.0"
date: 2026-10-27T17:30:00+02:00
draft: false
description: "Terraform CLI release by release, from 1.0 (June 2021) to 1.17 (October 2026): the headline features, notable enhancements and upgrade notes of every minor version, from moved blocks and import blocks to ephemeral values, Actions, terraform query and variables in provider requirements."
tags: ["terraform", "releases"]
categories: ["devops"]
---

A version-by-version tour of the notable features and changes in Terraform CLI,
starting with the 1.0 release in June 2021 and running through the latest
stable line. Bug-fix and dependency-only patch releases are omitted; the focus
is on the headline features, meaningful enhancements, and upgrade notes that
change how you write or run Terraform.

All details are drawn from the official
[HashiCorp Terraform CHANGELOG](https://github.com/hashicorp/terraform/blob/main/CHANGELOG.md),
the changelog of each version branch (`v1.0` to `v1.17`), and the dates of the
GitHub releases.

## At a Glance

| Version | Released | Headline feature |
| --- | --- | --- |
| 1.0 | Jun 8, 2021 | Stability release with compatibility promises |
| 1.1 | Dec 8, 2021 | `moved` blocks; `cloud` block; `nullable` variables |
| 1.2 | May 18, 2022 | `precondition` and `postcondition`; `replace_triggered_by` |
| 1.3 | Sep 21, 2022 | Optional object attributes with defaults |
| 1.4 | Mar 8, 2023 | `terraform_data` resource; plan files on errors |
| 1.5 | Jun 12, 2023 | `check` blocks; `import` blocks; config generation |
| 1.6 | Oct 4, 2023 | `terraform test` generally available |
| 1.7 | Jan 17, 2024 | `removed` blocks; test mocking |
| 1.8 | Apr 10, 2024 | Provider-defined functions |
| 1.9 | Jun 26, 2024 | Cross-object variable validation; `templatestring` |
| 1.10 | Nov 27, 2024 | Ephemeral resources and ephemeral values |
| 1.11 | Feb 27, 2025 | Write-only attributes; S3 native locking GA |
| 1.12 | May 14, 2025 | Import by resource identity; OCI Object Storage backend |
| 1.13 | Aug 20, 2025 | `terraform stacks` CLI; test improvements |
| 1.14 | Nov 19, 2025 | List resources, `terraform query`, and Actions |
| 1.15 | Apr 29, 2026 | Variables in module sources; deprecation markers |
| 1.16 | Aug 26, 2026 | `terraform_data` store block; action `on_failure` modes |
| 1.17 | Oct 21, 2026 | Variables in provider requirements; `-minimal-refresh`; Terraform Policy GA |

## Terraform 1.0 (June 8, 2021)

A stability release. Terraform 1.0.0 intentionally has no significant changes
compared to 0.15.5, and the 1.0 series is a direct continuation of 0.15. Its
purpose is the **v1.x Compatibility Promises**: configuration and automation that
works on 1.0 is meant to keep working across later 1.x minor releases, apart from
the exceptions listed in each version's upgrade notes. Every later release in this
article is covered by that promise.

## Terraform 1.1 (December 8, 2021)

- **`moved` blocks**: Module authors record in configuration that a resource or
  resource instance changed its address, and Terraform migrates the existing
  object during planning. Users of a shared module no longer have to run
  `terraform state mv` after upgrading it.
- **`cloud` block**: A new block inside the `terraform` settings for the native
  Terraform Cloud integration with the CLI-driven run workflow, including per-run
  variables with `-var` and workspace mapping by tags.
- **Deletion explanations**: `terraform plan` and `terraform apply` now say why an
  instance is planned for deletion, for example because `count` was lowered.

Enhancements included **nullable variables** (`nullable = false` makes a variable
fall back to its default instead of `null`), more precise type checking in
`terraform validate`, a `type()` function in the interactive console, and the
ability to delete a workspace whose state holds only data resources and outputs.

Upgrade notes:

- macOS 10.13 High Sierra or later is required.
- `terraform graph` no longer supports `-type=validate` and `-type=eval`.
- Applying a saved plan now verifies that the provider packages match the ones
  used to create the plan.
- `terraform state mv` errors on `-backup` and `-backup-out` without `-state` on
  non-local backends, instead of ignoring them silently.
- The AzureRM backend gained the opt-in `use_microsoft_graph` option.

## Terraform 1.2 (May 18, 2022)

- **`precondition` and `postcondition` blocks**: Resources, data sources, and
  module outputs can state assumptions and guarantees. When a condition fails,
  Terraform reports a custom error message.
- **`replace_triggered_by`**: A new `lifecycle` argument that replaces a resource
  when an upstream dependency changes.
- **`TF_TOKEN_` environment variables**: Credentials for Terraform-native
  services (Terraform Cloud and the registry) can be supplied with
  `TF_TOKEN_` followed by the encoded hostname.

Enhancements included error messages for conditions and variable validation that
are evaluated as expressions (so values can be interpolated), `TF_CLOUD_ORGANIZATION`
and `TF_CLOUD_HOSTNAME` fallbacks for the `cloud` block, OpenID Connect
authentication for the AzureRM backend, SSH over an HTTP proxy for provisioners,
and a warning when a provider-managed attribute is placed in `ignore_changes`.

Upgrade notes:

- The `TF_TOKEN_` variables take priority over `credentials` blocks and credential
  helpers. If you use the `terraform-credentials-env` helper plugin, disable it.
- Outgoing TLS connections made by the CLI require TLS 1.2 and reject SHA-1 signed
  CA certificates.
- Official Linux packages require kernel 2.6.32 or later.

## Terraform 1.3 (September 21, 2022)

- **Optional object attributes with defaults**: In an object type constraint an
  attribute can be declared `optional(type)`, or `optional(type, default)` with a
  default value. This concluded the long-running
  `module_variable_optional_attrs` experiment, and the experimental `defaults`
  function was removed.
- **New functions**: `startswith`, `endswith`, and `timecmp` (compares timestamps
  across UTC offsets).

```hcl
variable "settings" {
  type = object({
    a = string                # required
    b = optional(string)      # optional, null if unset
    c = optional(number, 127) # optional with a default
  })
}
```

Other enhancements: `terraform fmt` accepts several paths, `moved` blocks work
across separate module packages, and error messages for function calls now show
the function signature.

Upgrade notes:

- The `artifactory`, `etcd`, `etcdv3`, `manta`, and `swift` backends, and the
  legacy `azure` backend name, were removed.
- The AzureRM backend supports only Microsoft Graph (MSAL). ADAL support ended.
- `terraform import` no longer accepts `-allow-missing-config`: at least an empty
  resource block must exist.
- In `terraform show -json`, `after_unknown` carries more detail than a plain
  `true` or `false`, so consumers of the JSON may need updating.

## Terraform 1.4 (March 8, 2023)

- **`terraform_data` resource**: A built-in managed resource that can replace
  `null_resource` and can store data of any type.
- **Plan files on errors**: `terraform plan` can write a plan file even when it
  hits errors, so the failure can be inspected later.
- **`terraform workspace select -or-create`**: Creates the workspace when it does
  not exist, which helps automation.
- **`terraform metadata functions -json`**: Exports function signatures in a
  machine-readable form.

Enhancements included masked interactive input for sensitive variables, a `quiet`
argument for the `local-exec` provisioner, mTLS for the HTTP backend, `kms_encryption_key`
for the GCS backend, and a rewritten plan renderer with no intended output
changes. `yamlencode` stopped being documented as experimental.

Upgrade notes:

- `terraform init` now ignores entries in the global provider cache directory
  unless they match a checksum already in the dependency lock file.
- `textencodebase64` encodes the euro symbol differently for the GB18030, GBK, and
  CP936 encodings, to match the standards.
- Provider and module hostnames use non-transitional IDNA2008 mapping rules.

## Terraform 1.5 (June 12, 2023)

- **`check` blocks**: Independent assertions about infrastructure, optionally with
  a scoped data source. A failing check produces a warning but does not halt the
  run, so you can validate infrastructure outside the normal lifecycle.
- **`import` blocks**: Import became a configuration-driven action that is shown
  in `terraform plan`. The `id` had to be a plain string in this first version.
- **Generated configuration**: `terraform plan -generate-config-out=PATH` writes
  resource configuration for the objects an `import` block adopts.
- **New functions**: `plantimestamp` (the timestamp at plan time) and
  `strcontains`.

Enhancements included periodic persistence of state snapshots during apply, and
an immediate state save on SIGINT, which shrinks the window for lost state if the
process is aborted.

Upgrade notes: this is the last version that officially supports macOS 10.13 and
10.14, and the last that supports Windows 7, 8, Server 2008 and Server 2012.

## Terraform 1.6 (October 4, 2023)

- **`terraform test` generally available**: Tests are written in `.tftest.hcl`
  files as a series of `run` blocks. Each block executes a plan and an optional
  apply against the configuration and checks conditions on the result. This came
  with a significant change to how tests are written compared to the experimental
  version.

Enhancements:

- The `import` block `id` accepts expressions, as long as the value is a string
  known at plan time.
- Remote plans on Terraform Cloud can be saved with `-out`, viewed with
  `terraform show`, and applied from the saved file.
- Better tracking of what is known about unknown values, which lets `try`, `can`,
  and other functions give more precise results.
- Provider schemas are cached across provider instances, which lowers memory use
  for configurations with many instances of one provider.
- The Kubernetes backend can split state across several secrets, so it is no
  longer limited to 1 MiB.
- The S3 backend gained many options for consistency with the AWS provider, such
  as `assume_role_with_web_identity`, `custom_ca_bundle`, proxy settings,
  `retry_mode`, and `allowed_account_ids`.

Upgrade notes:

- macOS 10.15 Catalina and Windows 10 or Windows Server 2016 are now the minimum.
- S3 backend: IAM role settings move into a nested `assume_role` block, endpoint
  overrides move into an `endpoints` block, and the old top-level arguments are
  deprecated. `shared_credentials_file` is deprecated for the plural form, and
  `force_path_style` for `use_path_style`.

## Terraform 1.7 (January 17, 2024)

- **`removed` blocks**: Record in configuration that a resource or module call was
  removed, and say whether the real object should be destroyed or only forgotten.
  This is a plannable, configuration-driven alternative to `terraform state rm`.
- **Test mocking**: New blocks in `.tftest.hcl` files: `mock_provider`,
  `override_resource`, `override_data`, and `override_module`. Tests can run in
  `apply` mode without cloud credentials by creating fake resources.

Enhancements:

- `import` blocks accept `for_each` to import several instances.
- `terraform console -plan` evaluates expressions against the planned state.
- Test files can use functions, run outputs and variables in provider blocks, and
  load a `terraform.tfvars` from the test directory.
- A change rejected by a `postcondition` or `prevent_destroy` is now shown in the
  plan output next to the error.

Upgrade notes:

- `terraform graph` now produces a simplified resources-only graph by default. The
  old graph is available with `-type=plan`.
- S3 backend: `use_legacy_workflow` defaults to `false`, so credentials follow the
  same order as the AWS SDKs.
- Input validations are written to state again. Users on 1.3 to 1.5 who share
  remote state across minor versions should upgrade to 1.3.10, 1.4.7, or 1.5.7.

## Terraform 1.8 (April 10, 2024)

- **Provider-defined functions**: Providers can contribute functions to the
  language, called as `provider::provider_name::function_name()`.
- **Moving between resource types**: `moved` blocks can transfer a remote object
  between resources of different types, when the provider declares that it can
  convert one type to the other.
- **`issensitive` function**: Returns true when a value is marked sensitive.

Enhancements: `terraform show -json` plans carry the flags `applyable` and
`complete`; generated import configuration renders JSON strings as `jsonencode`
calls; lists of the same length now get a per-element diff in plan output;
`terraform providers lock` accepts `-enable-plugin-cache`; the built-in
`terraform` provider gained `encode_tfvars`, `decode_tfvars`, and `encode_expr`.

## Terraform 1.9 (June 26, 2024)

- **Cross-object validation**: Input variable `validation` rules can now refer to
  other variables and other objects, such as data resources, instead of only the
  variable being validated.
- **`templatestring` function**: Renders a template obtained dynamically, for
  example from a data source. It resembles `templatefile`.

Enhancements: `terraform init -json`; `removed` blocks can declare destroy-time
provisioners; `moved` refactoring from `null_resource` to `terraform_data`;
multi-line input in `terraform console`; and test runs can pass sensitive values
to input variables.

Upgrade notes:

- Provider version constraints are no longer allowed inside provider blocks in
  `.tftest.hcl` files. Put them in the main configuration.
- `import` blocks that point at a nonexistent module used to be ignored silently
  and now raise an error.

## Terraform 1.10 (November 27, 2024)

The 1.10 line introduced the ephemeral data model, which became the foundation
for several features in later releases.

- **Ephemeral resources**: A new kind of resource that is re-read during every
  phase of evaluation and is never written to state. Ephemeral resources always
  produce ephemeral values.
- **Ephemeral values**: Input variables and outputs can be marked ephemeral.
  These values are only usable in specific contexts and are never persisted to
  the plan or state file.
- **`ephemeralasnull` function**: Takes any value and returns the same type with
  ephemeral values replaced by non-ephemeral nulls, leaving other values intact.
- **`terraform modules -json`**: A new command that lists every installed module
  in a working directory and indicates whether each is still referenced by the
  configuration.

Enhancements included negative index support in the `element` function, better
`import` block validation during `terraform validate`, and performance gains for
configurations with large numbers of resource instances.

Upgrade notes worth flagging:

- The S3 backend gained native state locking; when combined with DynamoDB
  locking, locks are acquired from both. DynamoDB locking was slated for future
  deprecation.
- The S3 backend removed deprecated top-level IAM role assumption attributes in
  favor of the `assume_role` block.
- `moved` blocks now respect reserved keywords, so some resource references may
  need a `resource.` prefix.

## Terraform 1.11 (February 27, 2025)

- **Write-only attributes**: Providers can mark certain attributes as write-only.
  These are not stored in state and can accept ephemeral values, which pairs
  naturally with the ephemeral model from 1.10.
- **JUnit XML test reports GA**: The `-junit-xml` option on `terraform test`
  graduated from experimental to generally available, producing test reports in
  JUnit XML format.
- **S3 native state locking GA**: The `use_lockfile` argument became generally
  available. The DynamoDB-related arguments were deprecated in favor of it,
  though DynamoDB can still be used alongside S3 locking during migration.

Enhancements included `.netrc` credential support during provider installation,
new `terraform test` controls (`override_during`, `state_key`), and a
significantly refreshed Azure backend authentication stack that added options
like `use_cli`, `use_aks_workload_identity`, and various client credential file
paths.

## Terraform 1.12 (May 14, 2025)

- **OCI Object Storage backend**: A new backend implementation for Oracle Cloud
  Infrastructure Object Storage.
- **Import by resource identity**: `import` blocks can now target a resource via
  an `identity` attribute instead of `id` (the two are mutually exclusive).

Other enhancements:

- `terraform test` gained a `-parallelism=n` option and the ability to annotate
  runs for parallel execution.
- Logical binary operators can now short-circuit.
- `terraform init` is allowed when tests are present even if there are no
  configuration files directly in the current directory.

Upgrade note: on Linux, Terraform now requires kernel version 3.2 or later.

## Terraform 1.13 (August 20, 2025)

- **`terraform stacks` command**: A new CLI surface for stack operations, with
  subcommands that depend on the installed stacks plugin. Run
  `terraform stacks -help` to see what is available.

Enhancements centered heavily on testing and correctness:

- Filesystem functions are now checked for consistent results, catching invalid
  data during apply.
- `terraform init` succeeds when a provider constraint matches at least one
  valid version.
- `terraform test` gained parallel teardown, in-file definitions for external
  variables, and the ability for file-level variable blocks to reference run
  outputs and other variables.
- Type-checking error messages on mismatches were improved.

Notes: `terraform rpcapi` became generally available (though it is not intended
for public consumption). Upgrade note: external variables referenced in test
files should now be accompanied by a `variable` definition block in the test
file.

## Terraform 1.14 (November 19, 2025)

A large feature release built around querying and acting on existing
infrastructure.

- **List resources**: Defined in `*.tfquery.hcl` files, list resources let you
  query and filter existing infrastructure.
- **`terraform query` command**: Executes list operations against existing
  infrastructure, displays results, and can optionally generate configuration to
  import those results.
- **Actions**: A new top-level `action` block. Actions are provider-defined and
  codify use cases outside the normal CRUD model, such as `aws_lambda_invoke` or
  `aws_cloudfront_create_invalidation`. They can be triggered through a
  resource's lifecycle or via the `-invoke` CLI flag.
- A new `GenerateResourceConfiguration` RPC lets providers produce more precise
  configuration values during import.

Upgrade notes:

- Building Terraform 1.14 requires macOS Monterey or later (a consequence of the
  Go 1.25 toolchain).
- Operation parallelism inside container runtimes may be reduced depending on
  the CPU bandwidth limit.

## Terraform 1.15 (April 29, 2026)

- **Variables and locals in module sources**: Terraform now supports variables
  and locals in module `source` and `version` attributes, enabling dynamic
  module sources. As part of this, most commands now accept variable values.
- **Deprecation markers**: You can set a `deprecated` attribute on `variable` and
  `output` blocks. Terraform emits warnings when a deprecated variable is set or
  a deprecated output is referenced.
- **`convert` function**: Allows precise inline type conversions.
- **`backend` block validation**: `terraform validate` now checks the backend
  block for a valid type, required attributes, and backend-specific validation.
- New build targets: Windows ARM64, and Linux s390x (zLinux) from 1.15.4 on.
- The S3 backend supports authentication via `aws login`.

Enhancements included explicit type constraints on `output` blocks, re-enabled
PowerShell support in the SSH-based `file` and `remote-exec` provisioners,
better detection of deprecated resource attributes and blocks, and input
variable validation for stacks.

Upgrade note: the S3 backend's `AWS_USE_FIPS_ENDPOINT` and
`AWS_USE_DUALSTACK_ENDPOINT` environment variables now only honor `true` or
`false`, aligning with the AWS SDK for Go.

## Terraform 1.16 (August 26, 2026)

- **Provider private data across plan/apply**: Terraform now stores planned
  private data for providers, preserving provider-specific state between plan and
  apply.
- **`terraform_data` `store` block**: A new block that can hold ephemeral and
  sensitive values across plan and apply.
- **`import` blocks inside modules**: Now supported.
- **Action `on_failure` modes**: Resource action triggers can use `on_failure`
  modes of `halt`, `taint`, or `continue`, and actions gained `before_destroy`
  and `after_destroy` events.
- Providers can use nested blocks as computed values.
- Pre-built binary for Linux s390x (zLinux).

Notable enhancements:

- `terraform state show` and `terraform workspace list` can produce
  machine-readable output with `-json`.
- `terraform graph` can emit Mermaid diagrams via `-format=mermaid`.
- `terraform console` accepts an optional `-scope=<module address>` flag to
  evaluate expressions within a module or module instance.
- Resource `lifecycle` blocks support `destroy = false` to prevent destruction.
- The `contains()` function can test for `null` (and, as a fix, `merge()` no
  longer panics on `null` objects).
- `-invoke` can be combined with `-target` to identify the calling resource
  instance when several resources trigger the same action.

Upgrade note: `bastion_host_key` is now correctly applied by provisioners, so
verify the configured key before upgrading.

## Terraform 1.17 (October 21, 2026)

- **Variables and locals in provider requirements**: After module sources in
  1.15, provider requirements can now use variables and locals too, for example
  `version = local.null_version` inside `required_providers`. Terraform 1.16.4
  rejects that line with `Invalid version constraint`; 1.17.0 installs the
  provider.
- **`-minimal-refresh` planning option**: Refreshes only the resources that have
  proposed changes, instead of checking every object in the state for changes
  made outside Terraform.
- **Terraform Policy generally available**: The `-policies` flag for `plan`,
  `apply`, and `query` no longer needs an experimental build or
  `-allow-experimental-features`. Query policies evaluate the resources that list
  blocks discover, with human-readable or JSON results.

Enhancements: `mock_provider` in `terraform test` supports ephemeral resources,
`terraform init` logs include provider versions, and `terraform login` warns when
an organization's token TTL policy applies to the user.

Notes:

- `terraform version -json` now includes a `format_version` field
  (`"format_version": "1.0"` in 1.17.0), so the format can change safely later.
  Tools that read this output should start checking it.
- Terraform 1.17 is built with Go 1.26.10, which no longer trusts certificates
  issued through a set of compromised eMudhra intermediate CAs.
- The `log` and `pow` functions now raise an error instead of returning
  infinity or a value that is not a number.

## Notes on Method

This article summarizes the stable minor releases from 1.0.0 through 1.17.0. Patch releases that contained only bug fixes, dependency
bumps, or security patches are intentionally left out. For the complete,
authoritative record, including every patch release and CVE fix, consult the
per-version changelogs linked from the
[main CHANGELOG](https://github.com/hashicorp/terraform/blob/main/CHANGELOG.md).
