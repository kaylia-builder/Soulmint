# Soulmint

基于 Avalanche 的 MBTI AI 分身 NFT：选择 16 型人格，写入名字、口头禅与背景故事，铸造一个会被召唤、会成长、也记得易主经历的链上人格。

## 功能

- 16 种 MBTI 人格选择与实时 SVG 图案预览
- ERC-721 合约完全链上生成 NFT metadata 与 SVG 图案
- MetaMask 连接、Fuji 网络切换与 `0.01 AVAX` mint
- 灵魂档案、持有者、上一持有者、易主次数与成长进度
- AI 召唤对话；支持任意 OpenAI 兼容接口，无密钥时自动走规则人格
- 召唤次数驱动五阶段成长：初生 → 萌芽 → 觉醒 → 成熟 → 传奇

## 本地启动

```bash
npm install
cp .env.example .env.local
npm run dev
```

未填写 `NEXT_PUBLIC_SOULMINT_ADDRESS` 时，前端会清楚显示“演示模式”，铸魂数据保存在浏览器本机；钱包连接、人格预览、档案与聊天兜底均可体验。

## 合约测试与 Fuji 部署

项目使用 Foundry，合约不依赖外部 Solidity 包：

```bash
forge test
export FUJI_RPC_URL=https://api.avax-test.network/ext/bc/C/rpc
export DEPLOYER_PRIVATE_KEY=0x...
forge script script/Deploy.s.sol:Deploy --rpc-url fuji --private-key "$DEPLOYER_PRIVATE_KEY" --broadcast
```

把部署出的地址写入 `.env.local`：

```bash
NEXT_PUBLIC_SOULMINT_ADDRESS=0x...
```

然后重新构建前端。合约的 `recordSummon(tokenId)` 是公开入口，因此任何钱包都能为一次召唤写入成长记录；`transferFrom` / `safeTransferFrom` 会记录上一持有者与累计易主次数。

## AI 配置

所有 OpenAI 兼容服务都通过同一组变量接入：

```bash
LLM_BASE_URL=https://api.openai.com/v1
LLM_API_KEY=...
LLM_MODEL=gpt-4o-mini
```

DeepSeek、Moonshot 等服务只需替换 Base URL 与模型名。密钥仅用于服务端 `/api/chat`，不会下发到浏览器。

## 目录

- `contracts/Soulmint.sol`：ERC-721、链上 SVG、人格资料、成长与易主记忆
- `test/Soulmint.t.sol`：铸造、metadata、成长与转手测试
- `script/Deploy.s.sol`：Fuji 部署脚本
- `app/page.tsx`：铸魂台、灵魂档案、钱包与召唤 UI
- `app/api/chat/route.ts`：OpenAI 兼容聊天与规则兜底
