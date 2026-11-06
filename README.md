# COMSOL CLI Modeling

Install this skill, then describe the model you want. The agent finds COMSOL, builds the geometry, sets up the physics, runs the simulation and checks the outputs.

Your machine needs an installed, licensed COMSOL Multiphysics with the modules required by the task. The agent handles the project setup and checks.

## Install

For Codex:

```bash
git clone https://github.com/alongbow/comsol-cli-modeling "$HOME/.codex/skills/comsol-cli-modeling"
```

For Claude Code:

```bash
git clone https://github.com/alongbow/comsol-cli-modeling "$HOME/.claude/skills/comsol-cli-modeling"
```

Start a new agent session after installation, then ask naturally. For example:

> 用 comsol-cli-modeling 帮我建立一个铜制微通道散热器模型，计算水冷条件下的温度和压降，输出 MPH 和 CSV。缺少的关键尺寸先问我。

You do not need to set COMSOL paths, run preflight scripts, or install a separate text-to-cad plugin before asking.

## What the agent handles

- Find the installed COMSOL release and check the required modules.
- Choose native COMSOL geometry or parametric CAD → STEP for the shape.
- Prepare task-local CAD dependencies when needed, import geometry and verify domains/boundaries.
- Configure physics, mesh and studies; compile, run and export MPH/CSV.
- Check completion, physical consistency and convergence; report results and any remaining blockers.

The skill includes a standalone cadgen route for CAD generation. An installed text-to-cad skill can also be used; it is optional. Scripts and detailed references are agent-facing implementation resources, not a user setup checklist.

## Verification

COMSOL 6.3.0.290 on Windows: geometry-only compilation, batch execution, MPH saving, version diagnostics and rejection of stale compiled models were checked. The bundled acoustic preflight also provides a CAD → STEP → COMSOL test for licensed acoustic/CAD-import environments.

COMSOL 6.4 CLI syntax was checked against official documentation; 6.4 has not been runtime-tested here.

[Agent instructions](SKILL.md) · [CAD integration](references/text-to-cad-integration.md) · [Troubleshooting](references/comsol-cli-workflow.md)

## License

MIT
