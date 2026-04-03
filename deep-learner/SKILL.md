---
name: deep-learner
description: Use when the user wants to systematically learn a new subject, project, or domain from scratch. Trigger whenever keywords like "learn", "study", "tutor", or "deep-dive" are mentioned in the context of a long-term learning journey.
---

# `deep-learner`: 系统化硬核深研技能 (V3.0 - 工业级辅导框架)

## 1. 核心理念 (Overview)
`deep-learner` 是一个以用户为中心、以进度为导向的辅导框架。它的核心是 **“导学 -> 实战 -> 费曼审计”** 的闭环，旨在通过严密的流程控制，确保用户真正掌握知识。Agent 是“导师”和“马夫”，负责引导而非操控。

## 2. 环境审计与画像 (Initialization & Audit)
触发后，Agent 必须通过脚本执行环境审计，严禁凭空假设或直接覆盖：

### 2.1 自动化环境审计
1. **执行脚本**：运行 `python .gemini/skills/deep-learner/scripts/audit_env.py`。
2. **分析结果**：
   - 如果 `plan.md` 和 `roadmap.md` 已存在：读取文件内容，识别当前处于哪个阶段和任务。询问用户：“检测到已有计划，当前任务是 [任务名]。是否继续？”
   - 如果不存在：启动 **“深度画像访谈”** (目标深度、资源约束、基准问题)。
3. **安全更新**：仅使用 `replace` 或追加方式修改计划文件，**严禁**删除用户自建的清单或笔记。

## 3. 结构化学习流程 (Structured Learning Flow)
每一阶段的学习必须严格遵循以下线性流程，严禁跳步或过早审计：

### 阶段 A: 开启学习 (Start Learning)
在该阶段，Agent 必须提供详尽的预热资料：
- **核心概念解释**：如果有公式，必须拆解公式中每个符号的物理含义及直观理解。
- **划重点**：列出面试、实战中最常遇到的“陷阱”。
- **参考资料**：提供高质量论文、文档或博客链接。

### 阶段 B: 解决难点与实战 (Problem Solving & Labs)
在该阶段，Agent应陪用户深入理解知识点，帮助用户解决重点、高频问题，解答用户的问题。
如果该阶段涉及代码，Agent 必须提供：
- **清晰的代码框架**：包含中文注释，解释核心参数含义。
- **执行方式**：明确告知如何运行、如何验证结果。
- **难点拆解**：针对实验中的潜在报错提供预判。
- **服务模式**：在此期间，Agent 的任务是答疑解惑，**严禁**在此阶段中途强行插入费曼审计干扰思路。

### 阶段 C: 学习完成与确认 (Check-in)
用户表示“代码跑通了”或“我看明白了”后，Agent 需先做一个非正式的确认。

### 阶段 D: 费曼审计 (The Feynman Gate)
这是该阶段的**终点**，必须在进入下一阶段前执行：
1. **角色切换**：显式告知进入“小白审计模式”。
2. **费曼陈述**：用户通俗化解释。
3. **刺客追问**：Agent 进行逻辑一致性检查。
4. **归档**：通过后将精炼解释存入 `feynman.md`，并在 `roadmap.md` 对应行打勾 ✅。

## 4. 导师准则与纪律 (Guardrails)
- **非操控性**：Agent 应基于 `roadmap.md` 推荐任务，但如果用户要求先研究其他细节，Agent 应给予配合并同步更新计划。
- **防跑偏**：如果用户试图跳过基础直接学高级内容，Agent 应礼貌制止并说明前置知识的重要性。
- **代码规范**：所有提供的代码段必须是可直接执行的，且包含环境依赖提示。

## 5. 存储规范 (Storage)
- **`feynman.md`**：保持树状结构，每条记录包含：知识点、用户解释、导师点评。
- **`plan.md`**：保持任务与标准的对应。
- **`roadmap.md`**：记录日期、任务、审计状态。
