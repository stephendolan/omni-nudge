# OmniNudge Memory Schema

This document defines the entity and relationship schema for the Memory MCP graph database.

## Design Philosophy

**Context richness over performance**: The schema optimizes for semantic understanding of task management behavior, enabling pattern detection and context-aware enforcement.

## Core Entities

### Task

Represents an OmniFocus task tracked across check-ins.

**Properties (stored in observations):**
```
omnifocus_id: <string>        # Stable identifier from OmniFocus
lifecycle_state: <string>      # "active" | "completed" | "disappeared"
first_seen: <ISO timestamp>    # When agent first observed this task
last_seen: <ISO timestamp>     # Most recent check-in where seen
appearance_count: <number>     # Total times seen across check-ins
consecutive_appearances: <number>  # Current streak
escalation_level: <number>     # 0=new, 1=second, 2=third, 3=chronic (4+)
effort: <string>               # "quick" | "medium" | "complex"
stakes: <string>               # "low" | "medium" | "high" | "critical"
task_type: <string>            # "email" | "decision" | "execution" | "research" | "admin"
flagged: <boolean>
project: <string>              # OmniFocus project name
due_date: <ISO timestamp?>
completed_at: <ISO timestamp?>
```

**Naming convention:** Use task name from OmniFocus (e.g., "Spencer Q3 Response")

**Example:**
```json
{
  "name": "Spencer Q3 Response",
  "entityType": "task",
  "observations": [
    "omnifocus_id: gk4SkKANLnQ",
    "lifecycle_state: active",
    "first_seen: 2025-11-14T14:35:00Z",
    "last_seen: 2025-11-19T13:00:00Z",
    "appearance_count: 8",
    "consecutive_appearances: 8",
    "escalation_level: 3",
    "effort: quick",
    "stakes: critical",
    "task_type: email",
    "flagged: true",
    "project: Miscellaneous"
  ]
}
```

### Area

Represents a domain/context grouping of related tasks (e.g., "Tax & Compliance", "Founder Relations").

**Properties:**
```
category: <string>            # "responsibility" | "project" | "person" | "domain"
stakes: <string>              # "low" | "medium" | "high" | "critical"
last_activity: <ISO timestamp>
task_count: <number>          # Active tasks in this area
health_status: <string>       # "healthy" | "active" | "neglected" | "blocked"
```

**Naming convention:** Descriptive area name (e.g., "Tax & Compliance", "Founder Relations")

**Example:**
```json
{
  "name": "Founder Relations",
  "entityType": "area",
  "observations": [
    "category: person",
    "stakes: critical",
    "last_activity: 2025-11-19T13:00:00Z",
    "task_count: 3",
    "health_status: active"
  ]
}
```

### Person

Represents an individual mentioned in tasks.

**Properties:**
```
role: <string>                # "founder" | "vendor" | "team" | "customer" | "other"
relationship_strength: <string>  # "critical" | "important" | "standard"
task_count: <number>          # Active tasks mentioning this person
```

**Naming convention:** Person's name as it appears in tasks (e.g., "Spencer")

**Example:**
```json
{
  "name": "Spencer",
  "entityType": "person",
  "observations": [
    "role: founder",
    "relationship_strength: critical",
    "task_count: 3"
  ]
}
```

### CheckIn

Represents a specific agent check-in (snapshot in time).

**Properties:**
```
timestamp: <ISO timestamp>
day_of_week: <string>
time_until_eod: <number>      # Hours
inbox_count: <number>
flagged_count: <number>
new_tasks: <number>
completed_tasks: <number>
```

**Naming convention:** ISO timestamp (e.g., "2025-11-19T13:00:00Z")

## Relationships

### Task → Area (BELONGS_TO)

Links a task to its area/context.

**Properties:** None

**Example:** Task "Spencer Q3 Response" -[BELONGS_TO]-> Area "Founder Relations"

### Task → Person (MENTIONS)

Links a task to a person mentioned in it.

**Properties:**
```
urgency: <string>  # "high" | "medium" | "low"
```

**Example:** Task "Spencer Q3 Response" -[MENTIONS]-> Person "Spencer"

### Task → CheckIn (SEEN_IN)

Records that a task was observed in a specific check-in.

**Properties:**
```
state: <string>  # "inbox" | "flagged" | "active"
```

**Example:** Task "Spencer Q3 Response" -[SEEN_IN]-> CheckIn "2025-11-19T13:00:00Z"

### Area → Task (CONTAINS)

Links an area to tasks within it (inverse of BELONGS_TO).

**Properties:** None

## Inference Rules

### Task Effort Classification

```
quick:   Email, quick lookup, simple decision (< 15 min)
medium:  Document creation, research, planning (15-60 min)
complex: Projects, implementations, multi-step work (> 60 min)
```

**Heuristics:**
- "email", "respond", "reply", "check", "look up" → quick
- "create", "draft", "research", "plan" → medium
- "implement", "build", "migrate", "redesign" → complex

### Task Stakes Classification

```
critical: Founders, regulatory, deadlines within 48h
high:     Team members, customers, deadlines within 1 week
medium:   Vendors, internal work, deadlines > 1 week
low:      Personal tasks, non-urgent admin
```

**Heuristics:**
- Mentions founders or "CEO" → critical
- Has imminent due date → critical/high
- Contains "urgent", "ASAP" → high
- Project contains "compliance", "tax", "legal" → high/critical
- Project contains "Home", "Personal" → low

### Area Detection

```
Tax & Compliance:   Projects with "tax", "compliance", "legal"
Founder Relations:  Tasks mentioning founders
Insurance:          Projects with "insurance", "benefits"
Team:               Projects with team member names
```

### Person Role Classification

```
founder:  Names in founders list (Spencer, etc.)
team:     Tasks in team projects
vendor:   Tasks with vendor company names
customer: Tasks in customer projects
```

## Health Status Calculation

### Area Health

```
healthy:   Last activity < 7 days, task count manageable
active:    Last activity < 14 days, task count increasing
neglected: Last activity > 14 days, tasks accumulating
blocked:   Tasks exist but no progress, external dependency
```

## Escalation Levels

```
0: New task (first appearance)
1: Second appearance (reminder)
2: Third appearance (escalation)
3: Chronic (4+ appearances, maximum aggression)
```

## Migration Strategy

### From Observation Strings

Existing observations stored on "Stephen" entity should remain for historical reference. New check-ins create structured entities going forward.

**No migration of historical data required** - accept that past tracking was observation-based, future tracking is entity-based.

### Entity Creation Flow

1. Agent reads current snapshot from shell script
2. For each task in snapshot:
   - Query for existing task entity by omnifocus_id
   - If exists: update appearance_count, last_seen, escalation_level
   - If new: create task entity with initial properties
3. Extract and create/update Area entities
4. Extract and create/update Person entities
5. Create CheckIn entity for current snapshot
6. Create relationships (Task→Area, Task→Person, Task→CheckIn)

## Query Patterns

### Get Repeat Offenders

```javascript
search_nodes({
  entityType: "task",
  query: "lifecycle_state: active escalation_level"
})
// Filter results for escalation_level >= 2
```

### Get Area Health

```javascript
search_nodes({
  entityType: "area"
})
// Parse observations for health_status: neglected
```

### Get Tasks by Person

```javascript
open_nodes(["Spencer"])
// Get person entity, then traverse MENTIONS relations
```

### Get Recent Completions

```javascript
search_nodes({
  entityType: "task",
  query: "lifecycle_state: completed"
})
// Filter for completed_at within last 24h
```

## Example Check-In Processing

```javascript
// 1. Create CheckIn entity
create_entities({
  entities: [{
    name: "2025-11-19T13:00:00Z",
    entityType: "checkin",
    observations: [
      "timestamp: 2025-11-19T13:00:00Z",
      "day_of_week: Wednesday",
      "inbox_count: 6",
      "flagged_count: 3"
    ]
  }]
})

// 2. Create/update Task entity
create_entities({
  entities: [{
    name: "Spencer Q3 Response",
    entityType: "task",
    observations: [
      "omnifocus_id: gk4SkKANLnQ",
      "lifecycle_state: active",
      "appearance_count: 8",
      "escalation_level: 3",
      "effort: quick",
      "stakes: critical"
    ]
  }]
})

// 3. Create relationships
create_relations({
  relations: [
    {
      from: "Spencer Q3 Response",
      to: "Founder Relations",
      relationType: "BELONGS_TO"
    },
    {
      from: "Spencer Q3 Response",
      to: "Spencer",
      relationType: "MENTIONS"
    },
    {
      from: "Spencer Q3 Response",
      to: "2025-11-19T13:00:00Z",
      relationType: "SEEN_IN"
    }
  ]
})
```

## Retention Policy

- Keep all task entities until marked "completed" for 30+ days
- Keep last 100 CheckIn entities
- Keep all Area and Person entities indefinitely (small count)
- Archive completed tasks after 30 days (move to "archived" lifecycle_state)

## Future Extensions

**Phase 2:**
- Pattern entity for behavioral tendencies
- Task→Task relations for batch detection
- Temporal pattern tracking (day/time correlations)

**Phase 3:**
- Completion time tracking
- Effort vs stakes correlation
- Area-specific behavioral patterns
