# k3s manifests

Every workload deployed to the k3s cluster gets its manifest committed here,
one YAML file per service (e.g. `uptime-kuma.yaml`).

Why: the cluster's actual state (etcd) lives only on k3s1's disk. PBS backs
that VM up nightly, which covers total VM loss, but not same-day changes or
a fast recovery. If k3s1 is ever unrecoverable, the real safety net is being
able to install k3s fresh and run:

    kubectl apply -f k3s/manifests/

...and land back on the same set of workloads, versioned and reviewable like
everything else in this repo — rather than reconstructing it from memory.

Workflow: `kubectl apply -f <file>.yaml` to deploy, then commit that same
file here in the same change (or immediately after) so the repo never
drifts from what's actually running.
