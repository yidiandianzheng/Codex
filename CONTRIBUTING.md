# 贡献与反馈指南

感谢你帮助改进 Codex 算力条。

## 提交前先选对入口

- 稳定复现的错误：使用 [Bug 模板](https://github.com/yidiandianzheng/codex-pet-energy/issues/new?template=bug_report.yml)。
- 明确、可执行的新功能：使用 [功能建议模板](https://github.com/yidiandianzheng/codex-pet-energy/issues/new?template=feature_request.yml)。
- 还不确定方案、希望先交流：使用 [GitHub Discussions](https://github.com/yidiandianzheng/codex-pet-energy/discussions)。
- 安全或隐私问题：不要公开提交，参照 [SECURITY.md](SECURITY.md)。

提交前请搜索已有 Issues 和 Discussions，避免重复。

## 一条高质量建议应包含

1. 你遇到的具体场景。
2. 当前行为和期望行为。
3. 为什么现有方式不够用。
4. 最小可行方案。
5. 如果涉及界面，请附脱敏截图或简单示意。

请勿上传 Token、完整会话日志、个人账号信息或包含隐私的绝对路径。

## 本地开发

```bash
git clone https://github.com/yidiandianzheng/codex-pet-energy.git
cd codex-pet-energy
swift run CodexPetEnergy --self-test
swift build -c release
```

## Pull Request

1. 从 `main` 创建简短分支。
2. 每次只解决一个清楚的问题。
3. 保留现有产品边界：账户额度与项目 Token 分开呈现，缺失数据不冒充实时值。
4. 涉及行为变化时补充自测。
5. 在 PR 中写明改动原因、用户影响和验证命令。

提交 PR 即表示你同意按本仓库的 MIT License 发布贡献。
