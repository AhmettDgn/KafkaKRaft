"""Render-contract tests; these do not claim that Kafka runs."""
import os
import subprocess
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
HELM = os.environ.get("HELM_BIN", "helm")
CHART = ROOT / "lab/kafka-apache"


def render(*args, ok=True):
    proc = subprocess.run([HELM, "template", "kafka-lab", str(CHART), "-n", "kafka-lab", *args],
                          capture_output=True, text=True, encoding="utf-8")
    if ok and proc.returncode:
        raise AssertionError(proc.stderr)
    if not ok:
        return proc
    return list(yaml.safe_load_all(proc.stdout)), proc.stdout


def render_secure(*args, ok=True):
    digest = "sha256:" + "a" * 64
    proc = subprocess.run([HELM, "template", "kafka-secure", str(CHART), "-n", "kafka-secure",
                           "-f", str(ROOT / "deploy/contabo/secure-values.yaml.example"),
                           "--set", f"image.digest={digest}", *args], capture_output=True, text=True, encoding="utf-8")
    if ok and proc.returncode:
        raise AssertionError(proc.stderr)
    if not ok:
        return proc
    return list(yaml.safe_load_all(proc.stdout)), proc.stdout


class ChartTests(unittest.TestCase):
    def test_default_contract(self):
        docs, text = render()
        self.assertNotIn("/opt/bitnami", text)
        self.assertNotIn("bitnami/", text)
        self.assertNotIn("REPLACE_WITH", text)
        self.assertNotIn("KAFKA_CFG_", text)
        sts = next(d for d in docs if d["kind"] == "StatefulSet")
        self.assertEqual(3, sts["spec"]["replicas"])
        self.assertEqual("Parallel", sts["spec"]["podManagementPolicy"])
        pod = sts["spec"]["template"]["spec"]
        self.assertFalse(pod["automountServiceAccountToken"])
        self.assertEqual(1000, pod["securityContext"]["runAsUser"])
        container = pod["containers"][0]
        self.assertRegex(container["image"], r"apache/kafka:4\.0\.2@sha256:[a-f0-9]{64}$")
        self.assertTrue(container["securityContext"]["readOnlyRootFilesystem"])
        self.assertTrue(container["startupProbe"])
        self.assertTrue(container["readinessProbe"]["exec"])
        self.assertNotIn("initContainers", pod)
        self.assertEqual({"whenDeleted": "Retain", "whenScaled": "Retain"},
                         sts["spec"]["persistentVolumeClaimRetentionPolicy"])
        services = [d for d in docs if d["kind"] == "Service"]
        self.assertEqual(2, len(services))
        self.assertTrue(any(d["spec"].get("publishNotReadyAddresses") for d in services))
        self.assertTrue(all(d["spec"].get("type", "ClusterIP") == "ClusterIP" for d in services))
        self.assertFalse(any(d["kind"] == "Secret" for d in docs))

    def test_single_node_and_storage_override(self):
        docs, _ = render("--set", "replicaCount=1", "--set", "storage.storageClass=standard")
        sts = next(d for d in docs if d["kind"] == "StatefulSet")
        self.assertEqual(1, sts["spec"]["replicas"])
        self.assertEqual("standard", sts["spec"]["volumeClaimTemplates"][0]["spec"]["storageClassName"])

    def test_invalid_values_rejected(self):
        for assignment in ["replicaCount=2", "image.digest=sha256:fake", "existingClusterIdSecret=",
                           "clusterDomain=bad\nvalue", "storage.size=0Gi"]:
            with self.subTest(assignment=assignment):
                self.assertNotEqual(0, render("--set-string" if assignment.startswith("clusterDomain") else "--set",
                                             assignment, ok=False).returncode)

    def test_cluster_secret_override(self):
        docs, _ = render("--set", "existingClusterIdSecret=another-cluster-id")
        sts = next(d for d in docs if d["kind"] == "StatefulSet")
        env = sts["spec"]["template"]["spec"]["containers"][0]["env"]
        cluster = next(e for e in env if e["name"] == "CLUSTER_ID")
        self.assertEqual("another-cluster-id", cluster["valueFrom"]["secretKeyRef"]["name"])

    def test_secure_profile_contract(self):
        docs, text = render_secure()
        self.assertNotIn("bitnami/", text.lower())
        kinds = [d["kind"] for d in docs if d]
        for kind in ("StatefulSet", "ServiceAccount", "Role", "RoleBinding", "Job"):
            self.assertIn(kind, kinds)
        services = [d for d in docs if d and d["kind"] == "Service"]
        node_ports = [d for d in services if d["spec"].get("type") == "NodePort"]
        self.assertEqual([31092, 31093, 31094], [d["spec"]["ports"][0]["nodePort"] for d in node_ports])
        self.assertFalse(any(p["name"] == "controller" for d in node_ports for p in d["spec"]["ports"]))
        sts = next(d for d in docs if d and d["kind"] == "StatefulSet")
        container = sts["spec"]["template"]["spec"]["containers"][0]
        self.assertEqual({"client", "controller", "external", "metrics"}, {p["name"] for p in container["ports"]})
        mounts = {m["name"] for m in container["volumeMounts"]}
        self.assertTrue({"tls", "auth", "jmx-config"}.issubset(mounts))
        scripts = next(d for d in docs if d and d["kind"] == "ConfigMap" and d["metadata"]["name"].endswith("-scripts"))
        startup = scripts["data"]["start.sh"]
        for expected in ("SASL_SSL", "StandardAuthorizer", "-javaagent:", "listener.name.controller.ssl.client.auth=required"):
            self.assertIn(expected, startup)
        self.assertFalse(any(d and d["kind"] == "Secret" for d in docs))

    def test_secure_cross_field_validation(self):
        invalid = [
            ("security.enabled=true",),
            ("externalAccess.enabled=true",),
            ("metrics.serviceMonitor.enabled=true",),
            ("security.authorization.enabled=true",),
            ("extraConfig.listeners=PLAINTEXT://:9092",),
            ("extraConfig.ssl.client.auth=none",),
            ("rbac.create=true",),
        ]
        for assignments in invalid:
            args = tuple(part for value in assignments for part in ("--set", value))
            with self.subTest(assignments=assignments):
                self.assertNotEqual(0, render(*args, ok=False).returncode)
        secured = ("security.enabled=true", "security.tls.existingSecret=tls",
                   "security.sasl.existingSecret=auth", "externalAccess.enabled=true",
                   "externalAccess.advertisedHost=kafka.example.test",
                   "externalAccess.nodePorts[0]=31092", "externalAccess.nodePorts[1]=31093",
                   "externalAccess.nodePorts[2]=31094")
        args = tuple(part for value in secured for part in ("--set", value))
        self.assertNotEqual(0, render(*args, ok=False).returncode)

    def test_optional_prometheus_resources(self):
        docs, _ = render_secure("--set", "metrics.serviceMonitor.enabled=true",
                                "--set", "metrics.prometheusRule.enabled=true",
                                "--api-versions", "monitoring.coreos.com/v1/ServiceMonitor",
                                "--api-versions", "monitoring.coreos.com/v1/PrometheusRule")
        self.assertTrue(any(d and d["kind"] == "ServiceMonitor" for d in docs))
        self.assertTrue(any(d and d["kind"] == "PrometheusRule" for d in docs))

    def test_manual_deploy_configuration_and_rbac(self):
        self.assertFalse(list((ROOT / ".github/workflows").glob("*.y*ml")))
        docs = list(yaml.safe_load_all((ROOT / "deploy/contabo/lab-access.yaml").read_text()))
        self.assertFalse(any(d["kind"] in ("ClusterRole", "ClusterRoleBinding") for d in docs))
        for doc in docs:
            if doc["kind"] != "Namespace":
                self.assertEqual("kafka-lab", doc["metadata"]["namespace"])
        role = next(d for d in docs if d["kind"] == "Role")
        self.assertFalse(any("*" in r["resources"] or "*" in r["verbs"] for r in role["rules"]))
        ns = next(d for d in docs if d["kind"] == "Namespace")
        self.assertEqual("restricted", ns["metadata"]["labels"]["pod-security.kubernetes.io/enforce"])
        values = ROOT / "deploy/contabo/lab-values.yaml.example"
        docs, _ = render("-f", str(values))
        self.assertTrue(any(d["kind"] == "StatefulSet" for d in docs))
        secure_docs = list(yaml.safe_load_all((ROOT / "deploy/contabo/secure-access.yaml").read_text()))
        self.assertFalse(any(d["kind"] in ("ClusterRole", "ClusterRoleBinding") for d in secure_docs))
        self.assertTrue(all(d["metadata"].get("namespace", "kafka-secure") == "kafka-secure" for d in secure_docs))

    def test_legacy_chart_isolated_from_active_chart(self):
        legacy = ROOT / "legacy/bitnami-kafka"
        self.assertTrue((legacy / "Chart.yaml").is_file())
        self.assertTrue((legacy / "Chart.lock").is_file())
        self.assertTrue((legacy / "templates").is_dir())
        self.assertFalse((ROOT / "Chart.yaml").exists())
        self.assertFalse((ROOT / "templates").exists())

    def test_linux_text_has_no_crlf(self):
        files = [*ROOT.glob("scripts/**/*.sh"), *ROOT.glob("tests/*.sh"),
                 *CHART.glob("**/*"), *ROOT.glob("deploy/contabo/*.env"),
                 *ROOT.glob("deploy/contabo/*.example"), *ROOT.glob("images/**/*.sh"),
                 *ROOT.glob("images/**/Dockerfile")]
        for path in files:
            if path.is_file():
                with self.subTest(file=str(path.relative_to(ROOT))):
                    self.assertNotIn(b"\r", path.read_bytes())


if __name__ == "__main__":
    unittest.main(verbosity=2)
