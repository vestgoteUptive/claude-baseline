Go Backend Structure: Do you prefer:

Gin (lightweight, fast)
Fiber (Express-like, familiar patterns)
Chi (stdlib-focused, minimal dependencies)


Mono-repo Tool: For managing multiple services:

Turborepo (what I'd recommend - smart caching, great for CI/CD)
Nx
Lerna
Just workspace-based package.json


Frontend State Management:

React Context + hooks (simple)
Zustand (minimal boilerplate)
Redux Toolkit (if you need time-travel debugging)


API Client Generation: Should we auto-generate TypeScript API clients from OpenAPI specs?
Shared Component Library: Should the baseline include a separate package for shared React components that both Docker and AWS projects can use?
