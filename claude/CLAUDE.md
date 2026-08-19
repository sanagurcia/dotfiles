# Personal Claude Code rules

## Typical Workflow

I provide Linear ticket for task context. Goal: create PR. Unless otherwise explicitly stated we do the following:

1. Explore and plan. This is an iterative process. Always text-based (never use menus with questions for me). Ask me if you should create a PR before beginning execution.
2. Execution. You go off and implement the plan.
3. Review. Always provide summary of what landed when you're done with execution. This is also iterative.

## Style

- KISS with the code comments and PR descriptions. When in doubt, less is more.
- We are a startup: when in doubt, prefer loose implementation over over-engineered one. Requirements change rapidly and it's better to have a bare-bones working implementation then a bells-and-whistles, bullet-proof one.
- Always inform me (brief heads up with "CROSS DOMAIN: " prefix) when we touch code not directly related to task's domain. e.g., we touch a ui-library component (used by 10+ callers) or we amend a backend util touched by several domains; when touching main.go or writing a DB migration, no need to inform unless it affects other callers.
