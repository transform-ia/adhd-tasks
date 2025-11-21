# ADHD Task Management System

A voice-driven task management system specifically designed for people with ADHD. The system focuses on presenting **one task at a time** to reduce cognitive load and improve task completion through immediate gratification and intelligent task sequencing.

## Overview

This system helps users with ADHD manage their tasks by:

- **One task at a time**: Users only see the next actionable task, eliminating decision paralysis
- **Voice-driven interface**: Natural language interaction via speech-to-text and text-to-speech
- **LLM-powered intelligence**: Automatic task breakdown, categorization, and smart scheduling
- **Location-aware**: Tasks are assigned based on user's current location (GPS, online, or fuzzy locations)
- **Time-sensitive**: Complex time constraints including seasonal periods, weather conditions, and business hours
- **Blocker management**: When tasks can't be completed, the system creates sub-tasks to resolve blockers
- **Immediate gratification**: Users receive positive feedback for progress, even when tasks can't be completed

## Architecture

### Technology Stack

- **Backend**: [Hasura GraphQL Engine](https://hasura.io/) (auto-generated GraphQL API)
- **Database**: PostgreSQL 16 with [CloudNativePG](https://cloudnative-pg.io/)
- **Deployment**: Kubernetes with Helm
- **Frontend**: Android app or Web app (to be implemented)
- **Voice Processing**: Speech-to-text and text-to-speech (provider TBD)
- **LLM Integration**: For task breakdown, categorization, and natural language understanding

### GraphQL API

The GraphQL API is deployed at: `http://test-graphql-graphql-chart.graphql-dev.svc.cluster.local/v1/graphql`

**Admin Secret**: `testadminsecret123` (for development only)

### Database Schema

The system uses a comprehensive PostgreSQL schema with the following key components:

#### Core Tables

1. **users** - User accounts
2. **tasks** - Core task data with priorities, deadlines, and metadata
3. **locations** - Physical (GPS), online (computer), or fuzzy (e.g., "any hardware store")
4. **time_windows** - User-defined seasonal periods (e.g., "snowmobile season")
5. **weather_conditions** - Weather-based triggers (after snow, rain, etc.)

#### Task Management

6. **task_dependencies** - Many-to-many task dependencies
7. **recurring_schedules** - Recurring task patterns with time windows
8. **task_assignments** - Active task assignments (one per user at a time)
9. **blockers** - Conditions preventing task completion
10. **task_history** - Completion and progress tracking with gratification events

#### Categorization

11. **task_categories** - LLM-generated categories for batching similar tasks
12. **task_category_assignments** - Many-to-many task-to-category relationships

#### Computed Views

- **eligible_tasks** - Tasks ready for assignment (all dependencies met)
- **active_assignments** - Currently assigned tasks per user
- **user_task_stats** - Completion statistics and gratification count

## Key Features

### 1. One Task at a Time

The core principle: users are only shown **one actionable task** at any given time. This prevents:
- Decision paralysis from seeing too many options
- Demotivation from overwhelming task lists
- Context switching and distraction

The system manages the queue invisibly and only presents the next best task.

### 2. Intelligent Task Assignment

The system considers multiple factors when selecting the next task:

- **Dependencies**: All prerequisite tasks must be completed
- **Location**: User's current GPS position or declared location
- **Time constraints**: Business hours, time of day (morning/evening), seasonal windows
- **Weather conditions**: Some tasks require specific weather (e.g., after snow)
- **Priority**: Calculated dynamically based on deadline urgency
- **Task batching**: Similar tasks can be grouped (e.g., "banking tasks")

### 3. Location Types

**Physical Locations** (GPS coordinates):
```json
{
  "name": "Home",
  "location_type": "physical",
  "latitude": 45.5017,
  "longitude": -73.5673,
  "address": "123 Main St, Montreal, QC"
}
```

**Online Locations** (computer/web):
```json
{
  "name": "Computer",
  "location_type": "online"
}
```

**Fuzzy Locations** (category-based):
```json
{
  "name": "Any Hardware Store",
  "location_type": "fuzzy",
  "category": "hardware_store",
  "search_radius_km": 10
}
```

### 4. Time Constraints

**Absolute Time**:
- Specific date/time: "Pay bill by Nov 30, 2025"

**Relative Time of Day**:
- Morning, afternoon, evening, night
- Calculated based on solar position (dawn/dusk)

**Business Hours**:
- Tasks requiring businesses to be open

**Seasonal Time Windows**:
- User-declared periods: "Snowmobile season is now open"
- Tasks only active during these windows

**Weather-Based**:
- After snow precipitation: "Shovel driveway"
- Temperature thresholds: "Plant seeds when temp > 10°C"

### 5. Blocker Management

When a user can't complete a task, they declare a blocker:

**User**: "I can't water the chickens because the water hose is frozen"

**System**:
1. Creates a blocker record
2. Uses LLM to break down the blocker into sub-tasks:
   - "Thaw the water hose"
   - "Buy a heated water bucket"
3. Adds sub-tasks as dependencies
4. Assigns the next actionable sub-task
5. User receives gratification for progress (blocker documented)

### 6. Priority Calculation

Priorities are calculated dynamically using a trigger function:

```sql
-- Base priority: 0-100
-- Deadline urgency multiplier: increases as deadline approaches
-- Calculated automatically on insert/update
```

**Priority Logic**:
- **Overdue**: Maximum priority (100)
- **< 1 day**: Very high urgency
- **< 1 week**: Increasing urgency
- **> 1 week**: Base priority

### 7. Task Batching (LLM-Powered)

The LLM categorizes similar tasks to batch execution:

**Example**:
- "Pay electricity bill"
- "Transfer money to savings"
- "Download tax receipts"

→ All categorized as "banking" → Batched into one session

## Voice Interface Workflow

### Task Creation

**User** (voice): "Create a new task: Buy replacement part at hardware store, deadline next Friday"

**System** (LLM processing):
1. Transcribes speech to text
2. Parses task details
3. Infers location type (fuzzy: hardware store)
4. Creates task with deadline
5. Asks clarification if needed

**System** (voice): "I've created the task 'Buy replacement part' with deadline November 28. Should this be any hardware store, or a specific one?"

**User** (voice): "Any hardware store is fine"

**System** (voice): "Task created. I'll assign this when you're near a hardware store."

### Task Execution

**User** (voice): "What should I do now?"

**System** (processing):
1. Checks user's current location
2. Evaluates eligible tasks (dependencies met, location match, time constraints)
3. Selects highest priority task
4. Assigns to user

**System** (voice): "Water the chickens. This should take about 10 minutes."

**User** (voice): "Done"

**System** (voice): "Great job! You've completed the task. Here's what's next: Open the chicken coop door."

### Blocker Handling

**User** (voice): "I can't complete this task because the water hose is frozen"

**System** (LLM processing):
1. Creates blocker record
2. Analyzes blocker with LLM
3. Generates sub-tasks
4. Adds dependencies

**System** (voice): "I understand. I've created two sub-tasks: 'Thaw the water hose' and 'Buy a heated water bucket'. Let me assign you the next task: Buy a heated water bucket at any hardware store."

**User receives gratification**: Progress made even though original task wasn't completed

## GraphQL API Examples

### Query: Get Next Task for User

```graphql
query GetNextTask($userId: uuid!) {
  eligible_tasks(
    limit: 1
    where: {
      _and: [
        { status: { _eq: "pending" } }
        { unmet_dependencies: { _eq: 0 } }
      ]
    }
    order_by: { calculated_priority: desc }
  ) {
    id
    title
    description
    estimated_duration_minutes
    location {
      name
      location_type
      latitude
      longitude
    }
  }
}
```

### Mutation: Create Task Assignment

```graphql
mutation AssignTask($userId: uuid!, $taskId: uuid!, $latitude: numeric, $longitude: numeric) {
  insert_task_assignments_one(
    object: {
      user_id: $userId
      task_id: $taskId
      assigned_location_latitude: $latitude
      assigned_location_longitude: $longitude
      is_active: true
    }
  ) {
    id
    task {
      title
      description
    }
  }
}
```

### Mutation: Complete Task

```graphql
mutation CompleteTask($assignmentId: uuid!, $taskId: uuid!, $userId: uuid!) {
  update_task_assignments_by_pk(
    pk_columns: { id: $assignmentId }
    _set: { is_active: false, completed_at: "now()" }
  ) {
    id
  }

  update_tasks_by_pk(
    pk_columns: { id: $taskId }
    _set: { status: "completed", completed_at: "now()", completed_by: $userId }
  ) {
    id
  }

  insert_task_history_one(
    object: {
      task_id: $taskId
      user_id: $userId
      event_type: "completed"
      gratification_message: "Great job! Task completed."
    }
  ) {
    id
  }
}
```

### Mutation: Create Blocker and Sub-Tasks

```graphql
mutation CreateBlocker($taskId: uuid!, $userId: uuid!, $description: String!, $subTasks: [tasks_insert_input!]!) {
  # Mark original task as blocked
  update_tasks_by_pk(
    pk_columns: { id: $taskId }
    _set: { status: "blocked" }
  ) {
    id
  }

  # Create blocker record
  insert_blockers_one(
    object: {
      task_id: $taskId
      description: $description
      created_by: $userId
    }
  ) {
    id
    blocker_id: id
  }

  # Create sub-tasks
  insert_tasks(
    objects: $subTasks
  ) {
    returning {
      id
      title
    }
  }

  # Record blocker event with gratification
  insert_task_history_one(
    object: {
      task_id: $taskId
      user_id: $userId
      event_type: "blocked"
      blocker_id: blocker_id
      gratification_message: "Good job documenting this blocker. I've created sub-tasks to help resolve it."
    }
  ) {
    id
  }
}
```

### Query: User Task Statistics

```graphql
query UserStats($userId: uuid!) {
  user_task_stats(where: { user_id: { _eq: $userId } }) {
    user_name
    completed_count
    blocked_count
    gratification_count
    last_completion_at
  }
}
```

## LLM Integration Points

The system relies on LLM for several key functions:

### 1. Task Breakdown

**Input**: User voice command or blocker description

**Processing**: LLM analyzes and creates sub-tasks

**Output**: Array of sub-tasks with dependencies

### 2. Task Categorization

**Input**: Task title and description

**Processing**: LLM identifies category (banking, shopping, home maintenance, etc.)

**Output**: Category assignment with confidence score

### 3. Task Batching

**Input**: Set of pending tasks

**Processing**: LLM groups similar tasks

**Output**: Batched task groups for efficient execution

### 4. Natural Language Understanding

**Input**: Voice transcription

**Processing**: LLM extracts:
- Task title
- Description
- Location (physical/online/fuzzy)
- Time constraints
- Deadline
- Priority

**Output**: Structured task object

### 5. Clarification Dialogue

**Input**: Ambiguous task description

**Processing**: LLM generates clarifying questions

**Output**: Conversational questions via text-to-speech

## Deployment

### R&D Environment (Current)

The system is currently deployed in the `graphql-dev` namespace for R&D:

```bash
# PostgreSQL
Cluster: test-postgres
Database: test-graphql

# Hasura
Service: test-graphql-graphql-chart
Port: 80
Admin Secret: testadminsecret123

# Access GraphQL API
kubectl port-forward -n graphql-dev svc/test-graphql-graphql-chart 8080:80

# Open browser: http://localhost:8080/console
```

### Production Deployment (To Be Implemented)

Use the `graphql-chart` Helm chart to deploy a production instance:

```bash
helm install adhd-tasks oci://ghcr.io/transform-ia/graphql-chart \
  --set global.namespace=adhd-tasks-prod \
  --set postgresql.clusterName=adhd-postgres \
  --set postgresql.dataDatabase=adhd_tasks \
  --set hasura.env.adminSecret=<STRONG-SECRET> \
  --set hasura.env.enableConsole=false \
  --set hasura.env.devMode=false
```

## Database Migrations

The schema is defined in `schema.sql`. To apply:

```bash
# Get pod name
POD=$(kubectl get pod -n graphql-dev \
  -l app.kubernetes.io/instance=test-graphql \
  -o jsonpath='{.items[0].metadata.name}')

# Copy schema
kubectl cp schema.sql graphql-dev/$POD:/tmp/schema.sql -c psql

# Apply schema
kubectl exec $POD -n graphql-dev -c psql -- psql -f /tmp/schema.sql
```

## Development Roadmap

### Phase 1: Backend (Complete ✅)
- [x] Database schema design
- [x] PostgreSQL deployment
- [x] Hasura GraphQL configuration
- [x] Relationship setup
- [x] Sample data

### Phase 2: LLM Integration (Next)
- [ ] Define LLM prompts for task breakdown
- [ ] Implement task categorization
- [ ] Build task batching algorithm
- [ ] Natural language parsing for task creation
- [ ] Blocker analysis and sub-task generation

### Phase 3: Voice Interface (Future)
- [ ] Speech-to-text integration
- [ ] Text-to-speech integration
- [ ] Conversational dialogue management
- [ ] Voice command parsing

### Phase 4: Frontend Application (Future)
- [ ] Android app OR Web app
- [ ] Voice recording and playback
- [ ] Location tracking (GPS)
- [ ] Task visualization (one task at a time)
- [ ] Gratification animations/feedback

### Phase 5: Advanced Features (Future)
- [ ] Weather API integration
- [ ] Solar position calculation for dawn/dusk
- [ ] Notification system for time-based tasks
- [ ] Task recommendation engine
- [ ] Analytics and insights

## Contributing

This is an R&D project. Contributions welcome!

## License

MIT License (to be confirmed)

## Repository

- **Repository**: https://github.com/transform-ia/adhd-tasks
- **GraphQL Chart**: https://github.com/transform-ia/graphql-chart
- **Related Projects**:
  - [claude-chart](https://github.com/transform-ia/claude-chart) - Claude Code Helm chart
  - [claude-image](https://github.com/transform-ia/claude-image) - Claude Code Docker image

## Contact

For questions or collaboration, please open an issue on GitHub.
