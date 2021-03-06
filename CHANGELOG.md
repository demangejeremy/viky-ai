# Changelog

All notable changes to viky.ai will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)

## 2019-12

### Added

- viky.ai is released in open source, available on [Github](https://github.com/viky-ai/viky-ai).
- Users management: add sort by last sign up. [#21](https://github.com/viky-ai/viky-ai/pull/21)

### Changed

- Agents API: `GET /agents/:owner/:agent/interpret.json` parameter `language` will interpret only listed languages if specified. [#29](https://github.com/viky-ai/viky-ai/pull/29)

### Fixed

- Agent ownership transfert doesn't trigger NLP package synchronization. [#20](https://github.com/viky-ai/viky-ai/pull/20)
- Regression in chatbot feature when bots uses maps alone, inside cards or lists. [#19](https://github.com/viky-ai/viky-ai/pull/19)
