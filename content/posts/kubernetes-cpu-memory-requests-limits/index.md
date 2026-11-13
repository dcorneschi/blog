---
title: "Kubernetes CPU and Memory Requests and Limits: What Each Value Really Does"
date: 2026-11-13T12:00:00+02:00
draft: false
description: "Where requests and limits go after you apply a Pod: the scheduler's fit check, cgroup CPU shares and quotas, throttling that averages hide, memory limits and OOMKilled, eviction and OOM scores, QoS classes, LimitRange and ResourceQuota. Every output measured on a k3s v1.34.1 node."
tags: ["kubernetes", "resources", "cgroups"]
categories: ["devops"]
---

`requests` and `limits` sit next to each other in a Pod spec, but they are read by different parts of the system at different times. The scheduler reads the requests before the Pod exists on a node. The kubelet and the container runtime turn all four values into cgroup settings when the container starts. The Linux kernel enforces those settings while the container runs, and the kubelet uses them again when the node runs short of memory.

This article follows each value to the place where it takes effect, with real output for every step.

**Test setup.** Every command and output below comes from a single-node k3s v1.34.1 cluster (containerd 2, runc 1.5.2) on a node with 4 CPUs and 15.7 GiB of memory. That node uses **cgroup v1**, so the files are `cpu.shares`, `cpu.cfs_quota_us` and `memory.limit_in_bytes`. Most current distributions use **cgroup v2**, where the same values land in `cpu.weight`, `cpu.max` and `memory.max`; the article gives both, and the v2 numbers come from the conversion code in runc. One quirk of the test machine: it does not allow negative OOM scores, so Guaranteed pods showed `0` where a normal node shows `-997` (more in [OOM scores](#oom-scores)).

## 1. The Short Version

[![requests.cpu 500m is counted by the scheduler and becomes cpu.shares 512 (cpu.weight 59 on cgroup v2), a share of CPU under contention; limits.cpu 1 becomes a quota of 100000 microseconds per 100000 and throttles the container when it runs out; requests.memory 256Mi is counted by the scheduler but sets no cgroup file, it decides the eviction order and gives oom_score_adj 985; limits.memory 512Mi becomes memory.limit_in_bytes or memory.max and going over it means OOMKilled, exit code 137](requests-limits-map.svg)](requests-limits-map.svg "Open the diagram full size")

| Field | Read by | cgroup v1 | cgroup v2 | What goes wrong |
|-------|---------|-----------|-----------|-----------------|
| `requests.cpu` | Scheduler, then the kernel's CPU scheduler | `cpu.shares` | `cpu.weight` | Too low: the container gets a small share when CPUs are busy |
| `limits.cpu` | The kernel (CFS bandwidth control) | `cpu.cfs_quota_us`, `cpu.cfs_period_us` | `cpu.max` | Throttling: higher latency, even when the node has idle CPUs |
| `requests.memory` | Scheduler, kubelet eviction, OOM score | none | none (`memory.min`/`memory.low` stay 0) | Too low: the Pod is evicted or OOM-killed first when memory runs out |
| `limits.memory` | The kernel's memory controller | `memory.limit_in_bytes` | `memory.max` | `OOMKilled`, exit code 137 |

Two rules follow from this table and come up again in every section:

- The **scheduler reads only requests**. A container that sets a limit but no request gets a request equal to the limit (checked: `limits` of `700m`/`300Mi` alone produced `requests` of `700m`/`300Mi`, and the Pod became Guaranteed).
- **Limits act only on a running container**, and CPU and memory limits fail differently: going over the CPU limit makes the container wait, going over the memory limit kills it.

## 2. Units

| Value | Means |
|-------|-------|
| `cpu: 1` = `cpu: 1000m` | One CPU: a core or a hyperthread, depending on the node |
| `cpu: 500m` = `cpu: 0.5` | Half a CPU |
| `memory: 256Mi` | 268,435,456 bytes (binary: Ki, Mi, Gi, Ti) |
| `memory: 268M` | 268,000,000 bytes (decimal: k, M, G, T) |
| `memory: 400m` | 0.4 **bytes**: almost always a typo for `400Mi` |

Kubernetes accepts the typo and only warns about it. A dry run of a Pod with `memory: 400m` returned:

```
Warning: spec.containers[0].resources.requests[memory]: fractional byte value "400m" is invalid, must be an integer
```

## 3. Requests Decide Where a Pod Fits

The scheduler doesn't look at how much CPU or memory pods actually use. For each node it adds up the requests of the pods already there, adds the new Pod's requests, and compares the total with the node's **allocatable** capacity:

```
sum(requests of pods on the node) + requests of the new Pod <= allocatable
```

Allocatable is the node's capacity minus what is reserved for the operating system and Kubernetes (`kube-reserved`, `system-reserved`) and the eviction threshold. Managed clusters reserve part of every node this way, so allocatable is lower than the instance size; k3s reserves nothing by default, so on the test node allocatable equals capacity:

```bash
kubectl get node -o custom-columns='NAME:.metadata.name,CPU:.status.allocatable.cpu,MEMORY:.status.allocatable.memory'
```

```
NAME           CPU   MEMORY
01ba7039bf28   4     16472076Ki
```

Two Pods that only run `sleep`, one requesting 3 CPUs and one requesting 2:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: big-a
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: [sh, -c, sleep 3600]
      resources:
        requests:
          cpu: "3"
          memory: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: big-b
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: [sh, -c, sleep 3600]
      resources:
        requests:
          cpu: "2"
          memory: 1Gi
```

```
NAME    READY   STATUS    RESTARTS   AGE
big-a   1/1     Running   0          6s
big-b   0/1     Pending   0          6s
```

`big-a` uses almost no CPU, but its request holds 3 of the 4 CPUs, so `big-b` doesn't fit:

```bash
kubectl describe pod big-b
```

```
Warning  FailedScheduling  0/1 nodes are available: 1 Insufficient cpu.
```

`kubectl describe node` shows the same accounting under "Allocated resources", with the requests of the system Pods (CoreDNS and metrics-server) included:

```
  Resource           Requests     Limits
  --------           --------     ------
  cpu                3200m (80%)  0 (0%)
  memory             1164Mi (7%)  170Mi (1%)
```

A request is a reservation in the scheduler's books, not a partition of the machine: an idle Pod keeps its share reserved, and a busy Pod can use more than it requested when nothing else needs it.

## 4. CPU Requests Become a Weight

Linux has no "request" setting. When the container starts, the kubelet converts the CPU request into **shares**, 1024 per CPU, with a minimum of 2:

```
shares = millicores × 1024 / 1000
```

A container with `requests.cpu: 500m` and `limits.cpu: 1`:

```bash
kubectl exec res-demo -- cat /sys/fs/cgroup/cpu/cpu.shares
```

```
512
```

cgroup v2 has no `cpu.shares`; it has `cpu.weight`, with a range of 1 to 10000 and 100 as the default. The runtime converts the shares into a weight. runc 1.5 uses a curve that maps the minimum, the default and the maximum exactly (2 → 1, 1024 → 100, 262144 → 10000). Running its function (`ConvertCPUSharesToCgroupV2Value` in `github.com/opencontainers/cgroups`) on common requests:

| Request | `cpu.shares` | `cpu.weight` (cgroup v2) |
|---------|--------------|--------------------------|
| 10m | 10 | 4 |
| 100m | 102 | 17 |
| 250m | 256 | 35 |
| 500m | 512 | 59 |
| 1 | 1024 | 100 |
| 2 | 2048 | 174 |
| 4 | 4096 | 303 |

Older runtimes convert differently: runc 1.1 used the linear `1 + (shares - 2) × 9999 / 262142`, which gives 39 for 1 CPU instead of 100. The absolute numbers differ between nodes; the ratio between containers is what matters.

The weight only matters **when CPUs are busy**. Two Pods running four endless loops each (enough to fill all 4 CPUs), one requesting 500m and one 1500m, with no limits:

```bash
kubectl top pod
```

```
NAME         CPU(cores)   MEMORY(bytes)
burn-large   2920m        1Mi
burn-small   961m         1Mi
```

The CPUs are split 3:1, the same ratio as the requests. Over a 10-second window the cgroups' own counters (`cpuacct.usage`) showed 31.3 and 10.3 CPU-seconds. With `burn-large` deleted, the Pod with the 500m request is alone and takes almost the whole node:

```
NAME         CPU(cores)   MEMORY(bytes)
burn-small   3933m        0Mi
```

So a CPU request is a floor under contention, not a ceiling.

## 5. CPU Limits Become a Quota

A CPU limit is enforced with the kernel's CFS bandwidth control: the cgroup gets a **quota** of CPU time per **period** (100 ms by default). Once the processes in the cgroup have used the quota, all of them stop until the next period starts, whether or not other CPUs are idle.

| `limits.cpu` | cgroup v1: `cfs_quota_us` / `cfs_period_us` | cgroup v2: `cpu.max` |
|--------------|---------------------------------------------|----------------------|
| none | `-1` / `100000` | `max 100000` |
| 200m | `20000` / `100000` | `20000 100000` |
| 500m | `50000` / `100000` | `50000 100000` |
| 1 | `100000` / `100000` | `100000 100000` |
| 2.5 | `250000` / `100000` | `250000 100000` |

The four busy loops again, now with `limits.cpu: 500m`:

```bash
kubectl exec burn-limited -- cat /sys/fs/cgroup/cpu/cpu.cfs_quota_us /sys/fs/cgroup/cpu/cpu.stat
```

```
50000
nr_periods 15
nr_throttled 14
throttled_time 3207281508
```

Ten seconds later:

```
nr_periods 117
nr_throttled 116
throttled_time 26734314675
```

All 102 new periods were throttled, and `kubectl top` shows the Pod pinned at the limit:

```
NAME           CPU(cores)   MEMORY(bytes)
burn-limited   500m         1Mi
```

| Counter (`cpu.stat`) | Meaning |
|----------------------|---------|
| `nr_periods` | Periods in which the cgroup had something to run |
| `nr_throttled` | Periods in which it used up its quota and had to wait |
| `throttled_time` (v1, ns) / `throttled_usec` (v2) | Total time spent waiting; it counts each CPU, so it can grow faster than the clock |

On cgroup v2 the same file is `/sys/fs/cgroup/cpu.stat` inside the container. Prometheus gets these counters from cAdvisor as `container_cpu_cfs_periods_total` and `container_cpu_cfs_throttled_periods_total`.

### Throttling hides behind a low average

The quota is enforced every 100 ms, while dashboards average over a minute or more. A Pod can be throttled hard while its average looks comfortable.

The test: a Python program that, once per second, runs a burst of work on 4 worker processes (about 25 ms of CPU each, 100 ms in total), and prints how long the burst took. Run once with only `requests.cpu: 100m`, and once with `limits.cpu: 200m` added:

```
burst-nolimit:    24 ms   27 ms   13 ms   25 ms   25 ms   24 ms   25 ms   25 ms
burst-limit200m: 200 ms  300 ms  306 ms  293 ms  301 ms  306 ms  293 ms  203 ms
```

[![A burst on 4 cores that needs about 100 ms of CPU finishes after 25 ms without a limit; with limits.cpu 200m the quota of 20 ms per 100 ms period is used up after 5 ms on 4 cores, the cgroup is throttled until the next period, and the burst finishes after about 300 ms (measured 200 to 306 ms) while the pod averages only about 100m](cpu-throttling.svg)](cpu-throttling.svg "Open the diagram full size")

The limited Pod uses about 100m on average, half its limit, so a CPU graph shows nothing wrong. But a 200m limit means 20 ms of CPU per period, and 4 processes use that up in 5 ms of real time; the rest of the burst has to wait for the following periods. Every request this Pod served would have been 8 to 12 times slower.

The effect grows with the number of CPUs a process can see, because a CPU limit doesn't hide any CPUs. In a Pod with `limits.cpu: 200m` on the 4-CPU node, Python reported `os.cpu_count()` 4 and `multiprocessing.Pool()` started 4 workers, all sharing 20 ms of CPU per period. NGINX's `worker_processes auto` counts CPUs the same way. On a bigger node such programs start more workers and run out of quota even faster; set the worker count explicitly.

**When to set a CPU limit:**

- Set one when you need a hard cap: untrusted or batch workloads, per-tenant billing, or benchmarks that must not borrow idle CPU.
- For latency-sensitive services, many teams set a CPU **request** that covers normal load and **no CPU limit**. The request already protects the Pod's share under contention, and without a limit the Pod can use idle CPU during bursts.
- If you keep a limit, watch `nr_throttled` (or the throttled-periods ratio in Prometheus), not just average CPU, and size thread and worker pools to the limit rather than to the node.

## 6. Memory Requests Don't Limit Anything

A memory request is used for placement (section 3) and, later, for eviction and the OOM score (section 8). It sets no boundary in the cgroup. The container from section 4 requested 256Mi:

```bash
kubectl exec res-demo -- cat /sys/fs/cgroup/memory/memory.soft_limit_in_bytes
```

```
9223372036854771712
```

That is the "unlimited" value. On cgroup v2, `memory.min` and `memory.low` stay at `0` as well, unless the cluster enables the alpha **MemoryQoS** feature gate, which uses the request for reclaim protection (`memory.min`/`memory.low`).

So a container can use far more memory than it requested. That is fine as long as the node has memory to spare, and it is exactly what makes it the first candidate when the node runs out.

## 7. Memory Limits Kill the Container

A memory limit is a hard ceiling. When the container's memory reaches it, the kernel first tries to reclaim memory (for example page cache); if that isn't enough, the OOM killer kills a process inside the container. If that process is the container's main process, Kubernetes reports `OOMKilled`.

A Python program that keeps 10 MiB more allocated every step, with a 200Mi limit:

```python
import time

chunks = []
for i in range(1, 31):
    chunks.append(bytearray(10 * 1024 * 1024))   # keep 10 MiB more each step
    print(f"holding {i * 10} MiB", flush=True)
    time.sleep(0.2)
```

```yaml
      resources:
        requests:
          memory: 100Mi
        limits:
          memory: 200Mi
```

```bash
kubectl logs mem-limited --previous | tail -3
kubectl get pod mem-limited -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason} {.status.containerStatuses[0].lastState.terminated.exitCode}'
kubectl get pod mem-limited
```

```
holding 170 MiB
holding 180 MiB
holding 190 MiB
OOMKilled 137
NAME          READY   STATUS    RESTARTS      AGE
mem-limited   1/1     Running   3 (27s ago)   56s
```

The program's own data reached 190 MiB; the Python interpreter and its libraries made up the rest of the 200Mi. Exit code 137 is 128 + 9 (`SIGKILL`). With the default `restartPolicy: Always`, the kubelet restarts the container, and after a few attempts the Pod shows `CrashLoopBackOff`.

What counts toward the limit is more than the application's heap:

- the runtime itself: the interpreter, a JVM's metaspace, thread stacks and native buffers, Node.js memory outside the V8 heap;
- page cache for files the container reads and writes (the kernel can reclaim much of it before killing anything);
- files in a memory-backed `emptyDir` (`medium: Memory`): see [Kubernetes emptyDir Volumes]({{< ref "/posts/kubernetes-emptydir-volumes" >}}).

Memory limits are checked against the peak, not the average: startup, cache warm-up and garbage collection spikes are when containers get killed.

## 8. Eviction and OOM Scores

A container that reaches its own limit is killed even if the node has plenty of free memory. **Node-pressure eviction** is the other case: the whole node runs short.

### Eviction

When the node's available memory drops below the kubelet's eviction threshold (`memory.available<100Mi` by default), the kubelet first tries to reclaim memory and then evicts Pods. It ranks them by:

1. whether the Pod's memory usage is above its memory request,
2. the Pod's priority (`priorityClassName`),
3. how far the usage is above the request.

A Pod that stays under its memory request is evicted last. A Pod with a request far below its real usage is near the front of the queue.

### OOM scores

If memory runs out faster than the kubelet can evict, the kernel's OOM killer picks a process. It uses a badness score based on memory use, adjusted by each process's `oom_score_adj` (-1000 to 1000; higher means killed first). The kubelet sets `oom_score_adj` for every container from its QoS class. In the kubelet code (`pkg/kubelet/qos/policy.go` in v1.34.1):

| Class | `oom_score_adj` |
|-------|-----------------|
| Guaranteed, and node-critical Pods | -997 |
| BestEffort | 1000 |
| Burstable | `1000 - 1000 × memory request / node memory`, kept between 3 and 999 |

The lower bound of 3 (1000 - 997) keeps every Burstable container above the Guaranteed ones. On the test node (16,472,076 KiB), a 256Mi request gives 985 and a 100Mi request gives 994:

```bash
kubectl exec res-demo -- cat /proc/1/oom_score_adj
```

```
985
```

The bigger the memory request, the lower the score and the better the container's chance of surviving a node-wide shortage. A request set artificially low to squeeze a Pod onto a node does the opposite.

On the test machine the kernel doesn't allow lowering `oom_score_adj` below 0, so containerd was configured with `restrict_oom_score_adj = true` and Guaranteed Pods showed `0` instead of `-997`. The other values are unaffected.

## 9. QoS Classes

Kubernetes puts every Pod in one of three Quality of Service classes, based only on its requests and limits:

| Class | Rule |
|-------|------|
| **Guaranteed** | Every container has CPU and memory requests and limits, and each request equals its limit |
| **Burstable** | At least one container has a request or limit, but the Pod isn't Guaranteed |
| **BestEffort** | No container has any CPU or memory request or limit |

```bash
kubectl get pod <name> -o jsonpath='{.status.qosClass}'
```

Three Pods with the same container, once with no resources, once with `requests` of `cpu: 1` and `memory: 100Mi`, and once with the same values as `limits`:

```
qos-besteffort  BestEffort  shares=2     quota=-1      mem.limit=max        oom_score_adj=1000  /kubepods/besteffort
qos-burstable   Burstable   shares=1024  quota=-1      mem.limit=max        oom_score_adj=994   /kubepods/burstable
qos-guaranteed  Guaranteed  shares=1024  quota=100000  mem.limit=104857600  oom_score_adj=0     /kubepods/pode82657a7-…
```

[![BestEffort: no requests or limits, cpu.shares 2, no CPU quota, no memory limit, oom_score_adj 1000, cgroup /kubepods/besteffort; Burstable: some requests or limits, cpu.shares 1024, no quota, no memory limit, oom_score_adj 994, cgroup /kubepods/burstable; Guaranteed: requests equal limits for CPU and memory, cpu.shares 1024, quota 100000 per 100000, memory limit 104857600, oom_score_adj -997, cgroup /kubepods/pod-uid](qos-classes.svg)](qos-classes.svg "Open the diagram full size")

- A **BestEffort** container gets the minimum weight (2 shares, `cpu.weight` 1 on v2): under contention it gets almost nothing. It is also the first to be evicted and the first OOM victim.
- **Burstable** Pods share `/kubepods/burstable`; Guaranteed Pods sit directly under `/kubepods`.
- The class is fixed when the Pod is created. An in-place resize may change values but never the class.

## 10. Namespace Defaults: LimitRange and ResourceQuota

A cluster can fill in missing values and cap a namespace's total.

A **LimitRange** adds defaults to containers that don't set them:

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: defaults
  namespace: team-a
spec:
  limits:
    - type: Container
      defaultRequest:
        cpu: 100m
        memory: 128Mi
      default:            # becomes the limit
        memory: 256Mi
```

A **ResourceQuota** caps the sum of requests and limits in the namespace:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-a
  namespace: team-a
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 4Gi
    limits.memory: 8Gi
```

A Pod created without any resources gets the defaults, and the quota counts them:

```bash
kubectl run plain -n team-a --image=busybox:1.36 --restart=Never -- sleep 3600
kubectl get pod plain -n team-a -o jsonpath='{.spec.containers[0].resources}'
kubectl get resourcequota team-a -n team-a -o jsonpath='{.status.used}'
```

```
{"limits":{"memory":"256Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}
{"limits.memory":"256Mi","requests.cpu":"100m","requests.memory":"128Mi"}
```

A Pod that would go over the quota is rejected when it is created, not left Pending:

```
Error from server (Forbidden): pods "big" is forbidden: exceeded quota: team-a, requested: requests.cpu=3, used: requests.cpu=100m, limited: requests.cpu=2
```

Without the LimitRange, the same quota rejects every Pod that doesn't set the values it limits:

```
Error from server (Forbidden): pods "plain2" is forbidden: failed quota: team-a: must specify limits.memory for: plain2; requests.cpu for: plain2; requests.memory for: plain2
```

## 11. Exclusive CPUs

Normally all containers share all CPUs, and requests and limits only divide CPU time. The kubelet's **CPU Manager** with `--cpu-manager-policy=static` can give a container whole CPUs of its own, but only when the Pod is **Guaranteed** and the container's CPU request is a **whole number** (`2`, not `1500m`). Everything else stays in the shared pool. Changing the policy means draining the node and removing `/var/lib/kubelet/cpu_manager_state` before restarting the kubelet. This is for workloads where measurements show that CPU affinity or cache locality matters; it wasn't part of the tests above.

## 12. Choosing Values

- **CPU request:** what the container needs under normal load. Too low and it loses out whenever the node is busy; too high and it wastes schedulable capacity (the scheduler counts it whether it's used or not).
- **CPU limit:** often none for services; set one when you need a hard cap, and then watch throttling.
- **Memory request:** close to the container's real working set, so it is evicted only when it misbehaves. A low request is the cheapest way to get a Pod scheduled and the surest way to get it evicted.
- **Memory limit:** above the observed **peak**, with headroom. Many teams set memory request = limit, which makes the Pod's memory predictable and, with CPU request = limit too, Guaranteed.
- Measure before deciding: `kubectl top` for averages, `container_cpu_cfs_throttled_periods_total` for throttling, and `container_memory_working_set_bytes` for memory (the value `kubectl top` shows and the kubelet uses for eviction).

## Gotchas

- `kubectl top` and dashboards show averages. CPU throttling happens in 100 ms periods and can be invisible in them; check `cpu.stat` or the cAdvisor throttling counters.
- A memory limit kills; a CPU limit only slows down. Treat them differently.
- A container with only a limit gets a request equal to it, so the limit decides scheduling after all.
- `memory: 400m` is 0.4 bytes. Kubernetes accepts it with a warning.
- Requests are per container; the scheduler adds up all app containers of a Pod, including sidecars. Init containers run one at a time, so the Pod's request is the larger of that sum and the biggest init container's request.
- Allocatable is smaller than the node's capacity on most managed clusters; plan with `kubectl describe node` (Allocated resources), not with the instance size.
- On cgroup v2, the `cpu.weight` you see depends on the runtime version, because runc changed its conversion; only the ratio between containers matters.

## See Also

- [Kubernetes emptyDir Volumes]({{< ref "/posts/kubernetes-emptydir-volumes" >}}): memory-backed volumes count toward the memory limit
- [Kubernetes Cluster Autoscaler]({{< ref "/posts/kubernetes-cluster-autoscaler-guide" >}}): adds nodes for Pods that stay Pending because their requests don't fit
- [Kubernetes Pod Lifecycle Management]({{< ref "/posts/kubernetes-pod-lifecycle-management" >}})
- [Linux Memory: RSS vs VSZ]({{< ref "/posts/linux-memory-rss-vsz" >}})
