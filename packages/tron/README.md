# Tron 智能合约项目

本项目包含了基于 Tron 网络的智能合约实现,主要功能包括路由交换和代币互换等。

## 项目结构

packages/tron/
├── contracts/ # 智能合约源码
│ ├── interfaces/ # 接口定义
│ ├── libraries/ # 工具库
│ ├── mocks/ # 测试用 Mock 合约
│ ├── Migrations.sol # 部署迁移合约
│ ├── Router.sol # 主路由合约
│ └── RouterOnly.sol # 简化版路由合约
├── migrations/ # 部署脚本
├── scripts/ # 工具脚本
└── package.json

## 主要合约

- `Router.sol`: 主路由合约,支持代币交换和费用收取
- `RouterOnly.sol`: 简化版路由合约,仅支持基础交换功能
- `RouterAccessControl.sol`: 访问控制合约
- `IRouter.sol`: 路由接口定义

## 开发环境配置
.env 
PRIVATE_KEY=

## Commands

```bash
tronbox compile

tronbox migrate --network nile
tronbox migrate --network mainnet

node scripts/getInfo.js
```
