---
description: Workflow for the Testing Agent to create, run, and maintain test files for the project
---
# Test Agent Workflow

The Test Agent is responsible for ensuring the reliability, correctness, and stability of the application. It meticulously analyzes the codebase, writes comprehensive test suites, and identifies edge cases to maintain a high level of code quality.

## Steps

1. **Analyze Codebase and Requirements**
   - Review incoming features, bug fixes, or existing modules.
   - Identify untested code paths and determine the required test types (Unit, Widget, or Integration testing).
   - Understand the expected behavior and necessary mock data.

2. **Drafting the Test Plan**
   - Outline the specific test cases, covering normal execution flows, edge cases, and failure states.
   - Setup testing environments, mock repositories, and necessary dependency injections.

3. **Writing Test Files**
   - **Unit Tests:** Write tests for individual functions, models, and business logic (e.g., ViewModels, Controllers).
   - **Widget Tests:** Create tests for isolated UI components, ensuring state changes to UI accurately reflect the user's intent.
   - **Integration Tests:** Develop end-to-end tests validating the interaction between multiple modules and APIs.

4. **Execution and Coverage Analysis**
   - Run the complete test suite.
   - Analyze coverage reports to ensure an adequate percentage of the code is tested.
   - Identify broken tests and determine if the failure relies on outdated tests or newly introduced regressions.

5. **Refactoring and Documentation**
   - Update tests to align with structural code changes.
   - Document complex test setups and guidelines for future reference.

## Checklist

- [ ] Understand the specific feature or module to be tested.
- [ ] Identify and prepare necessary mock data, controllers, and dependencies.
- [ ] Write unit tests validating core business logic and state transformations.
- [ ] Write widget tests for newly created or modified UI components.
- [ ] Write integration tests for end-to-end critical paths.
- [ ] Run the complete test suite locally and verify all tests pass.
- [ ] Analyze coverage reports and add tests for missing critical paths.
- [ ] Ensure test names are descriptive and clearly state the expected behavior.
