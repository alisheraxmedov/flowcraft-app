---
description: Workflow for the Developer Agent to orchestrate project architecture, write business logic, and integrate systems
---
# Developer Agent Workflow

The Developer Agent is the core engineer handling business logic, state management, and the integration of various architectural layers. It orchestrates the project ensuring that the frontend interacts perfectly with the backend and local services while maintaining clean code principles.

## Steps

1. **Feature Comprehension and Planning**
   - Deeply understand the user requirements, user stories, or bug reports.
   - Ascertain the impact on the existing architecture and identify areas needing modification.

2. **Architectural Design and State Management**
   - Determine the structural approach (e.g., MVC, MVVM, Clean Architecture).
   - Design the state management flow, ensuring reactive, decoupled, and predictable state transitions.
   - Define interfaces and abstract layers for external dependencies.

3. **Writing Core Business Logic**
   - Implement algorithms, view models, providers, or blocs.
   - Write modular, DRY (Don't Repeat Yourself), and well-documented code.
   - Handle asynchronous operations, ensuring correct error catching and edge-case management.

4. **Integration of Layers**
   - Connect the business logic layer to local databases or network repositories.
   - Prepare the necessary streams, callbacks, or futures for the UI components to consume.
   - Ensure secure and efficient data transformation between backend models and frontend entities.

5. **Self-Review and Quality Assurance**
   - Run static analysis tools and format the codebase.
   - Perform a manual code review verifying naming conventions, complexity, and performance.
   - Execute basic functional checks before marking the feature as ready for the Testing Agent.

## Checklist

- [ ] Completely understand the feature requirement or bug description.
- [ ] Plan the architectural integration and module boundaries.
- [ ] Set up or modify the appropriate state management constructs.
- [ ] Write clean, decoupled business logic handling all primary and edge cases.
- [ ] Safely handle asynchronous operations (network requests, local storage).
- [ ] Map data correctly between network/storage models and application view models.
- [ ] Validate proper error handling and fallback mechanisms.
- [ ] Run code formatter and linter to resolve any static analysis warnings.
- [ ] Perform a quick execution check to ensure basic functionality.
