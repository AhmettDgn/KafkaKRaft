"""Roadmap artifacts and actual values experiments; offline, never deploys."""
import os
import re
import subprocess
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
RESEARCH = ROOT / "kafka-kraft-bitnami-image-research"
LEGACY = ROOT / "legacy/bitnami-kafka"
HELM = os.environ.get("HELM_BIN", "helm")


def template(chart, *values):
    command = [HELM, "template", "kafka-lab", str(chart), "-n", "kafka-lab"]
    for value in values:
        command.extend(["-f", str(value)])
    result = subprocess.run(command, capture_output=True, text=True, encoding="utf-8")
    if result.returncode:
        raise AssertionError(result.stderr)
    return result.stdout


class RoadmapTests(unittest.TestCase):
    def test_delivery_files_and_local_links(self):
        required = ["README.md", "DEMO-NOTES.md", "chart-analysis/kraft-architecture.md",
                    "chart-analysis/image-dependencies.md", "chart-analysis/bitnami-usage-points.md",
                    "alternatives/image-comparison.md", "alternatives/selected-image-decision.md",
                    "alternatives/manifest-evidence.md", "alternatives/security-evaluation.md",
                    "helm-values/original-values.yaml", "helm-values/non-bitnami-values.yaml",
                    "helm-values/image-only-override.yaml", "helm-values/diff-notes.md",
                    "tests/helm-template-output.md", "tests/deploy-notes.md",
                    "tests/producer-consumer-test.md", "tests/topic-management-test.md",
                    "screenshots/README.md"]
        for name in required:
            with self.subTest(file=name):
                self.assertTrue((RESEARCH / name).is_file())
        # Presence is not a semantic review or evidence that screenshots/tests exist.
        project_docs = [ROOT / name for name in
                        ["README.md", "ROADMAP-COMPLIANCE.md", "CHART-AUDIT.md",
                         "lab/kafka-apache/README.md", "deploy/contabo/README.md"]]
        for path in [*project_docs, *RESEARCH.rglob("*.md")]:
            text = path.read_text(encoding="utf-8")
            for target in re.findall(r"\]\(([^)]+)\)", text):
                if "://" in target or target.startswith("#"):
                    continue
                with self.subTest(file=str(path.relative_to(ROOT)), link=target):
                    self.assertTrue((path.parent / target.split("#")[0]).exists())

    def test_original_chart_image_only_is_not_runtime_port(self):
        text = template(LEGACY, LEGACY / "values-template.yaml",
                        RESEARCH / "helm-values/image-only-override.yaml")
        # Bitnami common renders repository@digest (tag omitted when digest is set).
        selected = yaml.safe_load((RESEARCH / "helm-values/image-only-override.yaml").read_text())["image"]
        self.assertIn(f'apache/kafka@{selected["digest"]}', text)
        self.assertIn("/opt/bitnami/scripts/libkafka.sh", text)
        self.assertIn("KAFKA_CFG_", text)
        self.assertIn("/opt/bitnami/kafka", text)
        # This is the EXPECTED negative finding: YAML rendering is not runtime compatibility.
        print("LEGACY image-only experiment: " + ", ".join(
            f"{pattern}={text.count(pattern)}" for pattern in
            ["/opt/bitnami", "libkafka.sh", "KAFKA_CFG_"]))

    def test_delivered_lab_values_render_with_exact_pvc_mount(self):
        text = template(ROOT / "lab/kafka-apache", RESEARCH / "helm-values/non-bitnami-values.yaml")
        for pattern in ["bitnami/", "/opt/bitnami", "KAFKA_CFG_", "REPLACE_WITH", "__ECR_"]:
            self.assertNotIn(pattern, text)
        docs = [d for d in yaml.safe_load_all(text) if d]
        sts = next(d for d in docs if d["kind"] == "StatefulSet")
        self.assertEqual(3, sts["spec"]["replicas"])
        pod = sts["spec"]["template"]["spec"]
        self.assertNotIn("initContainers", pod)
        self.assertEqual(1, len(pod["containers"]))
        kafka = pod["containers"][0]
        expected = yaml.safe_load((ROOT / "lab/kafka-apache/values.yaml").read_text())["image"]
        self.assertEqual(f'{expected["repository"]}:{expected["tag"]}@{expected["digest"]}',
                         kafka["image"])
        data = next(m for m in kafka["volumeMounts"] if m["name"] == "data")
        self.assertEqual("/var/lib/kafka/data", data["mountPath"])
        self.assertNotIn("subPath", data)
        pvc = sts["spec"]["volumeClaimTemplates"][0]
        self.assertEqual("local-path", pvc["spec"]["storageClassName"])
        self.assertEqual("5Gi", pvc["spec"]["resources"]["requests"]["storage"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
