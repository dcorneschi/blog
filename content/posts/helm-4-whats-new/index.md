---
title: "What's New in Helm 4"
date: 2026-10-30T22:30:00+02:00
draft: false
description: "Helm 4 in one page: server-side apply and its conflicts, kstatus wait strategies, post-renderer and signed plugins, OCI digests and the renamed flags (--rollback-on-failure, --force-replace), with every command run on Helm 4.3.1 and 3.22.1."
tags: ["helm", "kubernetes", "upgrades"]
categories: ["devops"]
---

Helm 4 was released on **November 12, 2025** at KubeCon + CloudNativeCon North
America in Atlanta — the first new major version in six years, coinciding with
the project's 10th anniversary. This is a summary of the major changes, new
features, and breaking changes. The commands were checked with Helm 4.3.1 and
Helm 3.22.1 against a k3s v1.35.0 cluster (Colima), using the chart that
`helm create chart` generates. The Helm 3 binary is called `helm3` below.

## Major Changes

### Server-Side Apply (SSA)

Helm 4 replaces the three-way merge method with Server-Side Apply, which has
been standard in Kubernetes since v1.22. Each field modification now has an
assigned owner, and conflicts generate explicit errors rather than silent
overwrites. The old three-way merge remains available with `--server-side=false`
for backward compatibility. The default is `--server-side=auto`: new releases use
SSA, and a release first installed by Helm 3 keeps client-side apply when Helm 4
upgrades it.

### Enhanced Resource Monitoring

Integration with the kstatus library provides much more accurate health status
checking. `--wait` now takes a strategy: `watcher` (kstatus, the default when
`--wait` is given alone), `hookOnly` (the default when the flag is omitted) or
`legacy`. Readiness annotations (`helm.sh/readiness-success` /
`helm.sh/readiness-failure`) for resource sequencing are proposed in HIP-0025,
but they are not in Helm 4.3.1.

### WebAssembly Plugin System

The plugin architecture was redesigned with an optional Wasm-based runtime for
better security. Three plugin types are now supported: CLI plugins, getter
plugins, and post-renderer plugins. Legacy plugins still work, but the new
system enables more customization of core functionality.

## New Features

- **OCI digest support** — install charts by digest for supply chain security
  (Helm 3.22.1 accepts the same reference):

  ```bash
  helm install dg oci://localhost:5050/charts/app@sha256:214d555fc57b9341e36bdc56f9bd5c09a3b267ce25422058d6f38e96c5e203bd --plain-http
  ```

  ```text
  Pulled: localhost:5050/charts/app@sha256:214d555fc57b9341e36bdc56f9bd5c09a3b267ce25422058d6f38e96c5e203bd
  Digest: sha256:214d555fc57b9341e36bdc56f9bd5c09a3b267ce25422058d6f38e96c5e203bd
  NAME: dg
  ```

- **Multi-document values** — split complex values across multiple YAML files.
- **Custom template functions** — extend templating through plugins.
- **Content-based caching** — smarter cache using a chart content hash instead
  of name/version.
- **Stable SDK API** — breaking changes are complete, enabling the future
  Charts v3 format.

## Breaking Changes

- **Post-renderers** must be implemented as plugins — you can no longer pass an
  executable directly to `--post-renderer`.
- **Registry login** — `helm registry login` requires the domain name only, not
  a full URL.
- **CLI flags renamed** (old names deprecated but still work):
  - `--atomic` → `--rollback-on-failure`
  - `--force` → `--force-replace`
- **Force replace needs client-side apply** — with the default SSA,
  `--force-replace` (and the deprecated `--force`) fails with
  `cannot use server-side apply and force replace together`; add
  `--server-side=false`.
- **`helm rollback --recreate-pods` is gone** — Helm 4 answers
  `Error: unknown flag: --recreate-pods`.

## Running Helm 3 and Helm 4 Side by Side

Both versions store releases the same way (Secrets in the release namespace),
so you can switch one release at a time. A release installed by Helm 3 and
upgraded by Helm 4:

```text
$ helm3 install web ./chart -n demo
NAME: web
STATUS: deployed
REVISION: 1

$ helm upgrade web ./chart -n demo
Release "web" has been upgraded. Happy Helming!

$ helm history web -n demo
REVISION  UPDATED                   STATUS      CHART        APP VERSION  DESCRIPTION
1         Fri Oct 30 22:46:16 2026  superseded  chart-0.1.0  1.16.0       Install complete
2         Fri Oct 30 22:46:16 2026  deployed    chart-0.1.0  1.16.0       Upgrade complete
```

Helm 3 reads the history Helm 4 wrote, and the other way round: a
`helm rollback web 1 -n demo` from Helm 4 shows up in `helm3 history` as
`Rollback to 1`.

The field manager on the Deployment shows which apply method was used. The
Helm 3 release stays on client-side apply (`Update`) under `--server-side=auto`;
one upgrade with `--server-side=true` moves it to SSA (`Apply`), and `auto`
keeps it there afterwards:

```text
$ kubectl get deploy web-chart -n demo \
    -o jsonpath='{range .metadata.managedFields[*]}{.manager}{"\t"}{.operation}{"\n"}{end}'
helm	Update
k3s	Update

$ helm upgrade web ./chart -n demo --server-side=true
Release "web" has been upgraded. Happy Helming!

$ kubectl get deploy web-chart -n demo -o jsonpath='...'
helm	Apply
k3s	Update
```

One thing breaks when both versions share a machine: Helm 3 cannot read the new
plugin format. Once a Helm 4 plugin is installed in the shared plugin directory,
every `helm3` command prints:

```text
failed to load plugins: failed to load plugin at "/Users/dcorneschi/Library/helm/plugins/add-label/plugin.yaml": error unmarshaling JSON: while decoding JSON: json: unknown field "apiVersion"
```

The command itself still runs. Give Helm 3 its own directory with
`HELM_PLUGINS` if the noise matters.

## --wait and --rollback-on-failure in Practice

Without `--wait`, neither version waits: an upgrade to an image tag that does
not exist reports `deployed` in about a second with Helm 3 and Helm 4 alike
(Helm 4's default is `hookOnly`). The difference is in what `--wait` tells you
when it fails. With a 30 second timeout:

```text
$ helm3 upgrade app ./chart -n w3 --set image.tag=nope2 --wait --timeout 30s
Error: UPGRADE FAILED: context deadline exceeded

$ helm upgrade app ./chart -n w4 --set image.tag=nope2 --wait --timeout 30s
level=WARN msg="upgrade failed" name=app error="resource Deployment/w4/app-chart not ready. status: InProgress, message: Pending termination: 1\ncontext deadline exceeded"
Error: UPGRADE FAILED: resource Deployment/w4/app-chart not ready. status: InProgress, message: Pending termination: 1

$ helm upgrade app ./chart -n w4 --set image.tag=nope3 --wait=legacy --timeout 30s
level=WARN msg="upgrade failed" name=app error="context deadline exceeded"
Error: UPGRADE FAILED: context deadline exceeded
```

The kstatus `watcher` names the resource that is not ready; `legacy` behaves
like Helm 3.

`--rollback-on-failure` works like `--atomic` did, starting from a healthy
release:

```text
$ helm3 upgrade app ./chart -n r3 --set image.tag=nope --atomic --timeout 30s
Error: UPGRADE FAILED: release app failed, and has been rolled back due to atomic being set: context deadline exceeded

$ helm upgrade app ./chart -n r4 --set image.tag=nope --rollback-on-failure --timeout 30s
level=WARN msg="upgrade failed" name=app error="resource Deployment/r4/app-chart not ready. status: InProgress, message: Pending termination: 1\ncontext deadline exceeded"
Error: UPGRADE FAILED: release app failed, and has been rolled back due to rollback-on-failure being set: resource Deployment/r4/app-chart not ready. status: InProgress, message: Pending termination: 1
context deadline exceeded

$ helm history app -n r4    # columns trimmed
REVISION  STATUS      DESCRIPTION
1         superseded  Install complete
2         failed      Upgrade "app" failed: resource Deployment/r4/app-chart not ready. ...
3         deployed    Rollback to 1
```

The rollback goes to the previous revision. If that revision was already
broken (it said `deployed` but its pods never became ready), the rollback
waits on it too and fails with
`an error occurred while rolling back the release`.

## Server-Side Apply Conflicts

This is the change most likely to stop a pipeline. Helm 3 silently resets a
field that someone changed with `kubectl`; Helm 4 refuses, because another
field manager owns it now. After a manual scale:

```text
$ kubectl scale deploy app-chart -n r4 --replicas=3
deployment.apps/app-chart scaled

$ helm upgrade app ./chart -n r4
level=WARN msg="upgrade failed" name=app error="conflict occurred while applying object r4/app-chart apps/v1, Kind=Deployment: Apply failed with 1 conflict: conflict with \"kubectl\" with subresource \"scale\" using apps/v1: .spec.replicas"
Error: UPGRADE FAILED: conflict occurred while applying object r4/app-chart apps/v1, Kind=Deployment: Apply failed with 1 conflict: conflict with "kubectl" with subresource "scale" using apps/v1: .spec.replicas
```

`kubectl patch` gives the same error with `conflict with "kubectl-patch"`. The
replicas stay at 3 and the release gets a `failed` revision. To take the field
back:

```text
$ helm upgrade app ./chart -n r4 --force-conflicts
Release "app" has been upgraded. Happy Helming!

$ kubectl get deploy app-chart -n r4 -o jsonpath='{.spec.replicas}'
1
```

After that, `helm` is the only manager of the Deployment's spec again.
`--force-conflicts` only exists for SSA:

```text
$ helm upgrade app ./chart -n r4 --force-conflicts --server-side=false
Error: UPGRADE FAILED: invalid client update option(s): forceConflicts enabled when serverSideApply disabled
```

If something scales the Deployment on purpose (an HPA), do not force: leave
`replicas` out of the manifest, which the generated chart already does when
`autoscaling.enabled` is true.

## Moving a Post-Renderer Script to a Plugin

A Helm 3 post-renderer was any executable; Helm 4 rejects it:

```text
$ helm upgrade app ./chart -n r4 --post-renderer ./script.sh
Error: invalid argument "./script.sh" for "--post-renderer" flag: plugin: {Name:./script.sh Type:postrenderer/v1} not found
```

The script itself can stay; it only needs a `plugin.yaml` next to it. This one
adds a label to every rendered object (manifests come in on stdin and go out on
stdout, as before):

```text
add-label/
├── add-label.sh
└── plugin.yaml
```

```sh
#!/bin/sh
# Adds a label to every top-level metadata.labels block of the rendered manifests (read on stdin)
sed '/^  labels:$/a\
    post-rendered: "true"
'
```

```yaml
apiVersion: v1
type: postrenderer/v1
name: add-label
version: 0.1.0
runtime: subprocess
runtimeConfig:
  platformCommand:
    - command: ${HELM_PLUGIN_DIR}/add-label.sh
```

```text
$ helm plugin install ./add-label
Installing plugin from local directory (development mode)
Installed plugin: add-label

$ helm plugin list
NAME       VERSION  TYPE             APIVERSION  PROVENANCE  SOURCE
add-label  0.1.0    postrenderer/v1  v1          local dev   unknown

$ helm upgrade app ./chart -n r4 --post-renderer add-label
Release "app" has been upgraded. Happy Helming!

$ kubectl get deploy,svc,sa -n r4 -l post-rendered=true
NAME                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/app-chart   1/1     1            1           103s

NAME                TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
service/app-chart   ClusterIP   10.43.206.97   <none>        80/TCP    103s

NAME                       AGE
serviceaccount/app-chart   103s
```

`--post-renderer` takes the plugin **name**, and arguments go through
`--post-renderer-args` as before. It works with `helm template` too.

In Helm 4.3.1, `helm plugin install` from a local directory symlinks into the
default plugin directory (`~/Library/helm/plugins` on macOS) even when
`HELM_PLUGINS` points elsewhere, while `helm plugin list` reads `HELM_PLUGINS`.

## Signed Plugins

Two new commands, `helm plugin package` and `helm plugin verify`, give plugins
the same provenance files charts have had. `package` signs by default and wants
a GnuPG keyring in the old `secring.gpg` format
(`gpg --export-secret-keys > secring.gpg`):

```text
$ helm plugin package ./add-label --key 'Blog Test' --keyring secring.gpg
Successfully signed. Signature written to: add-label-0.1.0.tgz.prov
Successfully packaged plugin and saved it to: add-label-0.1.0.tgz

$ helm plugin verify add-label-0.1.0.tgz --keyring pubring.gpg
Signed by: Blog Test <test@example.com>
Using Key With Fingerprint: 246A117F1CF0B4559D997A62705A586EB502E1FA
Plugin Hash Verified: sha256:f45ce6b5e585b0bbdd38668cb6576b1b8c253d6ce5ee4ff3d9b5efb02e554914
```

Installing from a tarball now checks the signature by default. An unsigned
tarball (`helm plugin package --sign=false`) is refused unless you opt out:

```text
$ helm plugin install unsigned/add-label-0.1.0.tgz
Verifying plugin signature...
Error: plugin verification failed: no provenance file (.prov) found

$ helm plugin install unsigned/add-label-0.1.0.tgz --verify=false
WARNING: Skipping plugin signature verification
Installed plugin: add-label
```

With the `.prov` file and the public key, `helm plugin list` shows the plugin
as `signed` in the `PROVENANCE` column. Local directories install as
`local dev` without a signature.

## Registry Login: Domain Only

Helm 3.22.1 accepts `http://localhost:5050`, `oci://localhost:5050` and
`localhost:5050/charts` and logs in to the host. Helm 4 refuses everything but
the host (and suggests it when the input is a repository path):

```text
$ echo "$PASSWORD" | helm registry login localhost:5050/charts -u testuser --password-stdin --plain-http
level=WARN msg="registry login currently only supports registry hostname, not a repository path" host=localhost:5050/charts suggested=localhost:5050
Error: invalid reference: invalid registry "localhost:5050/charts"

$ echo "$PASSWORD" | helm registry login http://localhost:5050 -u testuser --password-stdin --plain-http
level=WARN msg="registry login currently only supports registry hostname, not a repository path" host=http://localhost:5050 suggested=http:
Error: invalid reference: invalid registry "http://localhost:5050"

$ echo "$PASSWORD" | helm registry login localhost:5050 -u testuser --password-stdin --plain-http
Login Succeeded
```

For a URL the `suggested=` value is wrong (`http:`); strip the scheme yourself.

## Rollback and Uninstall

`helm rollback` gets the same SSA flags as `upgrade` (`--server-side`,
`--force-conflicts`, `--force-replace`) and loses `--recreate-pods`. The
deprecated `--force` hits the same SSA check:

```text
$ helm rollback app 1 -n r4 --force
Flag --force has been deprecated, use --force-replace instead
level=WARN msg="Rollback \"app\" failed: invalid operation: cannot use server-side apply and force replace together"
Error: invalid operation: cannot use server-side apply and force replace together

$ helm rollback app 1 -n r4 --server-side=false --force-replace
Rollback was a success! Happy Helming!
```

`helm uninstall --wait` takes a strategy as well, and here the default
`watcher` does not wait for the pods. The same release with two replicas,
uninstalled three ways:

```text
$ helm3 uninstall app -n u-h3 --cascade foreground --wait
release "app" uninstalled
  [2s] pods left: 0

$ helm uninstall app -n u-watcher --cascade foreground --wait
release "app" uninstalled
  [0s] pods left: 2

$ helm uninstall app -n u-legacy --cascade foreground --wait=legacy
release "app" uninstalled
  [2s] pods left: 0
```

(The time and pod count are from `date` and `kubectl get pods` right after each
command.) If a pipeline deletes a release and then reuses its names or volumes,
use `--wait=legacy` on Helm 4.3.1.

## Helm 3 vs Helm 4 Commands

The core command surface is unchanged — `install`, `upgrade`, `rollback`, etc.
work the same. The differences are in flags and a few behaviors. Most old flags
are deprecated but still work in Helm 4; `rollback --recreate-pods` is removed.

| Task | Helm 3 | Helm 4 |
|------|--------|--------|
| Roll back automatically on a failed upgrade | `helm upgrade myapp ./chart --atomic` | `helm upgrade myapp ./chart --rollback-on-failure` |
| Force resource replacement | `helm upgrade myapp ./chart --force` | `helm upgrade myapp ./chart --server-side=false --force-replace` |
| Take back fields changed with kubectl | not needed (silently overwritten) | `helm upgrade myapp ./chart --force-conflicts` |
| Log in to an OCI registry | `helm registry login registry.example.com` (URL tolerated) | `helm registry login registry.example.com` (domain only, not a full URL) |
| Use a post-renderer | `helm install myapp ./chart --post-renderer ./script.sh` (executable) | `helm install myapp ./chart --post-renderer <plugin>` (must be a plugin) |
| Install a chart by OCI digest | `helm install myapp oci://registry.example.com/charts/app@sha256:<digest>` | same command |
| Wait for an uninstall to finish | `helm uninstall myapp --wait` | `helm uninstall myapp --wait=legacy` |
| Recreate pods on rollback | `helm rollback myapp 1 --recreate-pods` | removed |
| Apply strategy | client-side three-way merge | Server-Side Apply (`--server-side=false` for three-way merge) |

## Performance Improvements

- Faster dependency resolution
- Content-based chart caching
- Clearer error messages
- Better OAuth and token support for private registries

## Compatibility

- Charts v2 remain fully compatible.
- Helm 3 is still supported and receiving updates (v3.20+).
- Backward compatibility was prioritized throughout the redesign.
- Requires Kubernetes 1.22+ for Server-Side Apply features.

## See Also

- [Comparing Helm Chart Versions Before an Upgrade](/posts/helm-compare-chart-versions/)
  runs `helm diff` (helm-diff 3.15) on Helm 4.3.

## Sources

- [Helm 4 Released (official blog)](https://docs.helm.sh/blog/helm-4-released)
- [Helm project history](https://docs.helm.sh/history/)
- [CNCF: Helm Marks 10 Years With Release of Version 4](https://www.cncf.io/announcements/2025/11/12/helm-marks-10-years-with-release-of-version-4/)

_Content summarized from the sources above; rephrased for compliance with licensing restrictions._
