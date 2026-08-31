"""Image-volume, upgrade-guard and runtime-evidence regression tests. No live cluster."""
import copy
import contextlib
import io
import json
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
from types import SimpleNamespace
from pathlib import Path

import yaml
from test_chart import ROOT, HELM, CHART, render

sys.path.insert(0, str(ROOT / "scripts/lab"))
import storage_audit as audit


class StorageTests(unittest.TestCase):
    def setUp(self):
        docs, _ = render()
        self.sts = next(d for d in docs if d["kind"] == "StatefulSet")

    def test_exact_image_volume_contract(self):
        contract = json.loads((ROOT / "tests/fixtures/apache-kafka-4.0.2-image.json").read_text())
        spec = self.sts["spec"]["template"]["spec"]
        audit.validate_spec(spec)
        container = spec["containers"][0]
        self.assertTrue(container["image"].endswith("@" + contract["digest"]))
        mounts = {m["mountPath"]: m for m in container["volumeMounts"]}
        self.assertTrue(set(contract["volumes"]).issubset(mounts))
        self.assertEqual("data", mounts[audit.VOLUME_ROOT]["name"])
        for path in set(contract["volumes"]) - {audit.VOLUME_ROOT}:
            self.assertTrue(mounts[path]["readOnly"])
        self.assertEqual("pvc-v2", self.sts["spec"]["template"]["metadata"]["annotations"]["kafka-lab/storage-layout"])

    def test_legacy_ancestor_mount_rejected(self):
        spec = copy.deepcopy(self.sts["spec"]["template"]["spec"])
        next(m for m in spec["containers"][0]["volumeMounts"] if m["name"] == "data")["mountPath"] = "/var/lib/kafka"
        with self.assertRaisesRegex(ValueError, "legacy layout"):
            audit.validate_spec(spec)

    def test_mountinfo_shadow_and_nested_and_missing_rejected(self):
        valid = "10 1 8:1 /k3s/storage/pvc-fixture /var/lib/kafka/data rw - ext4 /dev/test rw\n"
        self.assertEqual("/k3s/storage/pvc-fixture", audit.validate_mounts(valid))
        failures = [valid.replace("/k3s/storage/pvc-fixture", "/cri/containers/fixture/volumes/fixture"),
                    valid + "11 10 8:1 /other /var/lib/kafka/data/kraft rw - ext4 /dev/test rw\n",
                    valid.replace("/var/lib/kafka/data", "/var/lib/kafka"), valid + valid,
                    valid.replace("data rw", "data ro")]
        for fixture in failures:
            with self.subTest(fixture=fixture), self.assertRaises(ValueError):
                audit.validate_mounts(fixture)

    def test_identity_comparison_ignores_comments_but_not_directory_id(self):
        first = "#old timestamp\nversion=1\ncluster.id=fixture\nnode.id=0\ndirectory.id=directory-a\n"
        second = "#new timestamp\ndirectory.id=directory-a\nnode.id=0\ncluster.id=fixture\nversion=1\n"
        self.assertEqual(audit.metadata_identity(first, 0), audit.metadata_identity(second, 0))
        self.assertNotEqual(audit.metadata_identity(first, 0), audit.metadata_identity(second.replace("directory-a", "directory-b"), 0))
        with self.assertRaises(ValueError):
            audit.metadata_identity(first, 1)
        with self.assertRaises(ValueError):
            audit.metadata_identity(first + "directory.id=duplicate\n", 0)

    def test_snapshot_detects_pvc_or_metadata_replacement(self):
        before = {"kafka-lab-0": {"podUID": "old", "pvcUID": "same", "pv": "same", "mountRoot": "same",
                                  "identityHash": "same", "volumeIdentityHash": "same"}}
        after = copy.deepcopy(before)
        after["kafka-lab-0"]["podUID"] = "new"
        audit.compare_snapshots(before, after)
        for key in ("pvcUID", "pv", "mountRoot", "identityHash", "volumeIdentityHash"):
            changed = copy.deepcopy(after)
            changed["kafka-lab-0"][key] = "different"
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, "changed"):
                audit.compare_snapshots(before, changed)

    def test_live_upgrade_guard_through_helm_harness(self):
        # Real Helm executes the production helper against captured/fake lookup results.
        # The test-only chart is outside the repo and exposes no production bypass flag.
        with tempfile.TemporaryDirectory() as temporary:
            chart = Path(temporary)
            (chart / "templates").mkdir()
            (chart / "Chart.yaml").write_text("apiVersion: v2\nname: guard-test\nversion: 0.0.1\n")
            (chart / "templates/_helpers.tpl").write_text((CHART / "templates/_helpers.tpl").read_text())
            (chart / "templates/check.yaml").write_text('{{ include "lab.upgradeGuard" (dict "previous" .Values.previous "current" .) }}\napiVersion: v1\nkind: ConfigMap\nmetadata:\n  name: passed\n')
            values = yaml.safe_load((CHART / "values.yaml").read_text())
            cases = [(None, True), (self.sts, True)]
            legacy = copy.deepcopy(self.sts)
            legacy["spec"]["template"]["metadata"]["annotations"].pop("kafka-lab/storage-layout")
            changed = copy.deepcopy(self.sts)
            changed["spec"]["template"]["metadata"]["annotations"]["kafka-lab/identity-contract"] = "different"
            cases += [(legacy, False), (changed, False)]
            for previous, success in cases:
                values["previous"] = previous
                (chart / "values.yaml").write_text(yaml.safe_dump(values))
                result = subprocess.run([HELM, "template", "kafka-lab", str(chart), "-n", "kafka-lab"], capture_output=True, text=True)
                self.assertEqual(success, result.returncode == 0, result.stderr)

    def test_selectors_security_dns_and_storage_contract(self):
        docs, _ = render()
        labels = self.sts["spec"]["template"]["metadata"]["labels"]
        self.assertEqual(labels, self.sts["spec"]["selector"]["matchLabels"])
        for service in (d for d in docs if d["kind"] == "Service"):
            self.assertEqual(labels, service["spec"]["selector"])
        policy = next(d for d in docs if d["kind"] == "NetworkPolicy")["spec"]
        self.assertEqual(labels, policy["podSelector"]["matchLabels"])
        self.assertEqual(labels, policy["ingress"][1]["from"][0]["podSelector"]["matchLabels"])
        self.assertEqual(labels, policy["egress"][1]["to"][0]["podSelector"]["matchLabels"])
        self.assertEqual({"TCP", "UDP"}, {p["protocol"] for p in policy["egress"][0]["ports"]})
        pod = self.sts["spec"]["template"]["spec"]
        self.assertFalse(pod["automountServiceAccountToken"])
        self.assertEqual(1000, pod["securityContext"]["fsGroup"])
        container = pod["containers"][0]
        self.assertEqual(["ALL"], container["securityContext"]["capabilities"]["drop"])
        self.assertFalse(container["securityContext"]["allowPrivilegeEscalation"])
        self.assertEqual("data", self.sts["spec"]["volumeClaimTemplates"][0]["metadata"]["name"])

    def run_audit(self, arguments, response):
        calls = []

        def fake_run(command, **kwargs):
            calls.append(command)
            payload = response(command[3:])  # kubectl -n kafka-lab ...
            if not isinstance(payload, str):
                payload = json.dumps(payload)
            return SimpleNamespace(returncode=0, stdout=payload, stderr="")

        output = io.StringIO()
        with patch.object(audit.subprocess, "run", side_effect=fake_run), \
                patch.dict(audit.os.environ, {"KUBECONFIG": "fixture", "NAMESPACE": "kafka-lab", "RELEASE_NAME": "kafka-lab"}), \
                patch.object(sys, "argv", ["storage_audit.py", *arguments]), contextlib.redirect_stdout(output):
            audit.main()
        return calls, output.getvalue()

    def test_cli_fresh_install_refuses_orphan_pvcs_and_api_errors(self):
        def fresh(words):
            return "" if words[:2] == ["get", "statefulset"] else {"items": []}
        calls, _ = self.run_audit(["--pre-deploy"], fresh)
        self.assertEqual(3, len(calls))

        def orphan(words):
            if words[:2] == ["get", "pvc"]:
                return {"items": [{"metadata": {"name": "old-data"}}]}
            return fresh(words)
        with self.assertRaisesRegex(ValueError, "recovery review"):
            self.run_audit(["--pre-deploy"], orphan)
        with patch.object(audit.subprocess, "run", return_value=SimpleNamespace(returncode=1, stdout="", stderr="denied")), \
                patch.dict(audit.os.environ, {"KUBECONFIG": "fixture"}), \
                patch.object(sys, "argv", ["audit", "--pre-deploy"]):
            with self.assertRaisesRegex(ValueError, "kubectl read failed"):
                audit.main()

    def test_cli_legacy_block_happens_before_pod_operations(self):
        legacy = copy.deepcopy(self.sts)
        legacy["spec"]["template"]["metadata"]["annotations"] = {}
        calls = []

        def response(words):
            calls.append(words)
            return legacy
        with self.assertRaisesRegex(ValueError, "UNSAFE LEGACY"):
            self.run_audit(["--pre-deploy"], response)
        self.assertEqual(1, len(calls))
        self.assertEqual(["get", "statefulset"], calls[0][:2])

    def test_cli_three_pod_pvc_audit_and_snapshot(self):
        sts = copy.deepcopy(self.sts)
        sts["metadata"]["uid"] = "statefulset-fixture"

        def response(words):
            if words[:2] == ["get", "statefulset"]:
                return sts
            ordinal = int(words[2][-1]) if words[0] == "get" else int(words[1][-1])
            name = f"kafka-lab-{ordinal}"
            pv = f"pvc-fixture-{ordinal}"
            if words[:2] == ["get", "pod"]:
                spec = copy.deepcopy(sts["spec"]["template"]["spec"])
                spec["volumes"].append({"name": "data", "persistentVolumeClaim": {"claimName": "data-" + name}})
                return {"metadata": {"uid": f"pod-{ordinal}", "ownerReferences": [{"uid": "statefulset-fixture"}]}, "spec": spec}
            if words[:2] == ["get", "pvc"]:
                return {"metadata": {"uid": f"claim-{ordinal}"}, "status": {"phase": "Bound"},
                        "spec": {"volumeName": pv, "storageClassName": "local-path"}}
            path = words[-1]
            if path == "/proc/self/mountinfo":
                return f"10 1 8:1 /k3s/storage/{pv}_kafka-lab_data-{name} {audit.VOLUME_ROOT} rw - ext4 /dev/test rw\n"
            if path == "/work/server.properties":
                return "log.dirs=" + audit.DATA_DIR + "\n"
            if path.endswith("/meta.properties"):
                return f"version=1\ncluster.id=fixture\nnode.id={ordinal}\ndirectory.id=directory-{ordinal}\n"
            if path.endswith("/.lab-volume-identity"):
                return f"pvc-v2|fixture|{ordinal}|3|kafka-lab|kafka-lab|cluster.local\n"
            raise AssertionError(words)

        with tempfile.TemporaryDirectory() as directory:
            snapshot = str(Path(directory) / "before.json")
            calls, output = self.run_audit(["--snapshot", snapshot], response)
            self.assertIn("Result: PASS", output)
            self.assertEqual(3, len(json.loads(Path(snapshot).read_text())))
            self.assertTrue(all(c[3] in ("get", "exec") for c in calls))
            self.run_audit(["--compare", snapshot], response)


if __name__ == "__main__":
    unittest.main(verbosity=2)
