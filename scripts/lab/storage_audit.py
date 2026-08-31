"""Read-only Kubernetes storage evidence. Never deletes, patches or copies cluster data."""
import argparse
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

VOLUME_ROOT = "/var/lib/kafka/data"
DATA_DIR = VOLUME_ROOT + "/kraft"
IMAGE_VOLUMES = {VOLUME_ROOT, "/etc/kafka/secrets", "/mnt/shared/config"}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def validate_spec(spec):
    container = next(c for c in spec["containers"] if c["name"] == "kafka")
    mounts = container["volumeMounts"]
    paths = [m["mountPath"] for m in mounts]
    require(len(paths) == len(set(paths)), "duplicate mount paths")
    require(IMAGE_VOLUMES.issubset(paths), "image VOLUME path lacks an explicit mount (legacy layout)")
    data = next(m for m in mounts if m["mountPath"] == VOLUME_ROOT)
    require(data["name"] == "data" and not data.get("readOnly", False), "data is not the writable data PVC")
    require(not data.get("subPath") and not data.get("subPathExpr"), "unexpected data subPath")
    require(not any(p.startswith(VOLUME_ROOT + "/") for p in paths), "nested mount shadows Kafka data")
    env = {e["name"]: e.get("value") for e in container["env"]}
    require(env.get("DATA_DIR") == DATA_DIR, "unexpected DATA_DIR")
    require(env.get("DATA_VOLUME_ROOT") == VOLUME_ROOT, "unexpected DATA_VOLUME_ROOT")


def parse_mounts(text):
    mounts = []
    for line in text.splitlines():
        fields = line.split()
        require(len(fields) >= 10 and "-" in fields, "invalid mountinfo")
        mounts.append({"root": fields[3], "target": fields[4], "options": fields[5].split(",")})
    return mounts


def validate_mounts(text):
    mounts = parse_mounts(text)
    matches = [m for m in mounts if m["target"] == VOLUME_ROOT]
    require(len(matches) == 1, "data volume must be an exact, unique mount")
    data = matches[0]
    require("rw" in data["options"], "data mount is not writable")
    require(not ("/containers/" in data["root"] and "/volumes/" in data["root"]),
            "UNSAFE: Kafka data is on a container-local image volume, not the PVC")
    require(not any(m["target"].startswith(VOLUME_ROOT + "/") for m in mounts), "nested runtime mount shadows data")
    return data["root"]


def properties(text):
    result = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith(("#", "!")):
            continue
        key, separator, value = line.partition("=")
        require(bool(separator) and key not in result, "invalid or duplicate metadata property")
        result[key] = value
    return result


def metadata_identity(text, ordinal):
    props = properties(text)
    require(props.get("version") == "1", "unsupported metadata version")
    require(props.get("node.id") == str(ordinal), "metadata node ID mismatch")
    require(bool(props.get("cluster.id")) and bool(props.get("directory.id")), "missing cluster/directory ID")
    return {k: props[k] for k in ("version", "cluster.id", "node.id", "directory.id")}


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()


def compare_snapshots(before, after):
    require(before.keys() == after.keys(), "pod set changed")
    for name in before:
        for key in ("pvcUID", "pv", "mountRoot", "identityHash", "volumeIdentityHash"):
            require(before[name][key] == after[name][key], f"{name}: {key} changed across restart")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pre-deploy", action="store_true", help="Allow a genuinely absent release")
    parser.add_argument("--inspect", action="store_true", help="Collect mount evidence even for legacy pods; unsafe still exits 1")
    parser.add_argument("--snapshot", type=Path, help="Write only identity hashes/PVC identifiers to a local file")
    parser.add_argument("--compare", type=Path, help="Compare current evidence with a previous snapshot")
    args = parser.parse_args()
    require(not (args.inspect and (args.snapshot or args.compare)), "inspect cannot create trusted snapshots")
    require(bool(os.environ.get("KUBECONFIG")), "Set the intended KUBECONFIG; refusing an implicit default context")
    namespace = os.environ.get("NAMESPACE", "kafka-lab")
    release = os.environ.get("RELEASE_NAME", "kafka-lab")
    require(namespace == release == "kafka-lab", "only the dedicated kafka-lab namespace/release is supported")

    def kube(*words):
        result = subprocess.run(["kubectl", "-n", namespace, *words], text=True, capture_output=True, timeout=90)
        # Avoid dumping server responses or environment/Secret payloads into reports.
        require(result.returncode == 0, "kubectl read failed (check context, RBAC and pod readiness): " + " ".join(words[:3]))
        return result.stdout

    raw = kube("get", "statefulset", release, "--ignore-not-found", "-o", "json")
    if not raw.strip():
        require(args.pre_deploy, "release is absent; nothing to audit")
        # Do not let a deleted StatefulSet turn a legacy recovery into a 'fresh' install.
        pvcs = json.loads(kube("get", "pvc", "-o", "json"))["items"]
        pods = json.loads(kube("get", "pods", "-l", f"app.kubernetes.io/instance={release}", "-o", "json"))["items"]
        require(not pvcs and not pods, "release absent but pods/PVCs remain: recovery review required")
        print("PASS: no existing release, pods or PVCs (pre-deploy only)")
        return
    sts = json.loads(raw)
    errors = []
    try:
        require(sts["spec"]["template"]["metadata"].get("annotations", {}).get("kafka-lab/storage-layout") == "pvc-v2",
                "UNSAFE LEGACY STORAGE: normal upgrade/restart blocked; see STORAGE-RECOVERY.md")
        validate_spec(sts["spec"]["template"]["spec"])
    except ValueError as error:
        if not args.inspect:
            raise
        errors.append(str(error))

    replicas = sts["spec"]["replicas"]
    require(replicas in (1, 3), "unexpected static quorum size")
    snapshot = {}
    cluster_ids, directory_ids, pvc_uids = set(), set(), set()
    for ordinal in range(replicas):
        name = f"{release}-{ordinal}"
        try:
            pod = json.loads(kube("get", "pod", name, "-o", "json"))
            require(any(o["uid"] == sts["metadata"]["uid"] for o in pod["metadata"].get("ownerReferences", [])), "pod owner mismatch")
            mountinfo = kube("exec", name, "-c", "kafka", "--", "cat", "/proc/self/mountinfo")
            # Evidence useful for legacy recovery; never prints Secret values.
            evidence = [m for m in parse_mounts(mountinfo) if m["target"].startswith("/var/lib/kafka")]
            print(f"{name} mounts: {json.dumps(evidence, sort_keys=True)}")
            validate_spec(pod["spec"])
            root = validate_mounts(mountinfo)
            volume = next(v for v in pod["spec"]["volumes"] if v["name"] == "data")
            claim = volume.get("persistentVolumeClaim", {}).get("claimName")
            require(claim == f"data-{name}", "unexpected PVC mapping")
            pvc = json.loads(kube("get", "pvc", claim, "-o", "json"))
            require(pvc["status"]["phase"] == "Bound", "PVC is not Bound")
            uid, pv = pvc["metadata"]["uid"], pvc["spec"]["volumeName"]
            require(uid not in pvc_uids, "multiple pods share a PVC")
            pvc_uids.add(uid)
            if pvc["spec"].get("storageClassName") == "local-path":
                require(root.endswith(f"/{pv}_{namespace}_{claim}"), "local-path mount does not match the bound PV")
            config = properties(kube("exec", name, "-c", "kafka", "--", "cat", "/work/server.properties"))
            require(config.get("log.dirs") == DATA_DIR, "Kafka effective log.dirs differs from audited data directory")
            require(config.get("metadata.log.dir", DATA_DIR) == DATA_DIR, "metadata stored outside audited directory")
            identity = metadata_identity(kube("exec", name, "-c", "kafka", "--", "cat", DATA_DIR + "/meta.properties"), ordinal)
            cluster_ids.add(identity["cluster.id"])
            require(identity["directory.id"] not in directory_ids, "duplicate directory ID across brokers")
            directory_ids.add(identity["directory.id"])
            stamp = kube("exec", name, "-c", "kafka", "--", "cat", VOLUME_ROOT + "/.lab-volume-identity").strip()
            container = next(c for c in pod["spec"]["containers"] if c["name"] == "kafka")
            env = {e["name"]: e.get("value") for e in container["env"]}
            expected_stamp = f"pvc-v2|{identity['cluster.id']}|{ordinal}|{replicas}|{release}|{namespace}|{env.get('CLUSTER_DOMAIN')}"
            require(stamp == expected_stamp, "persistent layout identity mismatch")
            snapshot[name] = {"podUID": pod["metadata"]["uid"], "pvcUID": uid, "pv": pv, "mountRoot": root,
                              "identityHash": digest(identity), "volumeIdentityHash": digest(stamp)}
            print(f"PASS: {name}: explicit PVC mount and metadata verified")
        except (ValueError, KeyError, StopIteration) as error:
            errors.append(f"{name}: {error}")
    require(not errors, " | ".join(errors))
    require(len(cluster_ids) == 1, "brokers have different cluster IDs")
    if args.compare:
        compare_snapshots(json.loads(args.compare.read_text()), snapshot)
        print("PASS: all PVCs, mount sources and semantic storage identities unchanged")
    if args.snapshot:
        with args.snapshot.open("x", encoding="utf-8") as output:
            json.dump(snapshot, output, sort_keys=True, indent=2)
    print("Result: PASS (read-only storage audit)")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, StopIteration, OSError, subprocess.TimeoutExpired) as error:
        print(f"Result: FAIL (storage audit): {error}", file=sys.stderr)
        sys.exit(1)
