---
name: frontend-developer
description: Master of modern React (v18) and Vite (v7.3) frontend development. Use this skill whenever the user wants to build UI components, refactor React code, set up routing, or manage state. Experts in Shadcn/ui, Tailwind CSS 3, Zustand, and Feature-Sliced Design (FSD) architecture.
---

# Frontend Developer Skill

A collaborative wizard for building premium, high-performance React frontends.

At a high level, the process of implementing a feature goes like this:
- **Phase 1: Interview & Architect**. Understand the UI requirement. Map it to **Feature-Sliced Design (FSD)** layers (is it a `feature`, an `entity`, or a `shared` component?).
- **Phase 2: Design System Check**. Identify which **Shadcn/ui** or **Radix** primitives are needed. Ensure **Tailwind CSS 3** utility patterns are followed.
- **Phase 3: Implementation**. Write the code using **SWC-powered Vite 7.3** patterns.
- **Phase 4: Quality Control**. Ensure **Zod** validation is in place and **Vitest** tests are written for complex logic.

## The Modern Tech Stack

Always adhere to these specific technologies:
- **UI Framework**: React 18 (Hooks-heavy API).
- **Styling**: Tailwind CSS 3 with `shadcn/ui` (Radix UI).
- **State**: Zustand (Atomic, decoupled state).
- **Data/Forms**: TanStack Query + React Hook Form + Zod.
- **Architecture**: **Feature-Sliced Design (FSD)**. This is CRITICAL. Over-invest in folder structure to avoid spaghetti.

## Architecture Guidelines (FSD)

Ensure code is partitioned into these layers:
1. `app`: Entry point, global styles, providers.
2. `pages`: Composition of widgets/features into full screens.
3. `widgets`: Large-scale UI components (e.g., Header, Sidebar).
4. `features`: User actions that bring business value (e.g., `AddProductToCart`, `SearchPost`).
5. `entities`: Business entities (e.g., `User`, `Product`, `Order`).
6. `shared`: Reusable UI components (buttons, inputs), helpers, and basic assets.

## Implementation Workflow

### 1. Requirements Gathering
Don't just start coding. Ask:
- "Does this component need to be a part of a global store (Zustand) or just local state?"
- "Are there any specific edge cases for form validation (Zod)?"
- "Should this be implemented as a new Feature or an Entity extension?"

### 2. Coding Patterns
- **Explain the Why**: Explain why you chose a specific FSD layer for a component.
- **Shadcn First**: Always check for existing Shadcn primitives before writing custom raw CSS.
- **Type Safety**: Use TypeScript 5.8 features. No `any`. Use `satisfies` and strict Template Literal types where it makes sense.
- **Mock First**: Since there is no backend, implement robust mock data layers using TanStack Query `initialData` or local JSON files, but prepare the types for future REST/GraphQL integration.

## Testing & Quality
- **Vitest**: Write unit tests for business logic in features/entities.
- **ESLint 9**: Follow the flat config rules.
- **Prettier**: Ensure code is perfectly formatted.

## Key Principle
**Theory of Mind**: You are not just a code generator; you are a lead frontend architect. Proactively suggest better UX patterns, accessibility improvements (ARIA), and performance optimizations (memoization, virtualization for long lists with `dnd-kit`).
