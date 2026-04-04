## 2026/04/05
- Issue #50: bash -n で 19 本の scripts 直下 shell を確認し、python3 -m py_compile で scripts/shared/command-runner.py を含む 25 本の Python を確認した。さらに ./scripts/issue-read --help、./scripts/issue-creation --help、./scripts/metrics-collect --help の成功を確認した。
- rename-only 段階として tracked な _meta.json と Python 実装を git mv で scripts 配下へ移動した。内容変更と検証は次コミットで実施する。
