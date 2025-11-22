-- ADHD Task Management System - Database Schema
-- PostgreSQL schema for Hasura GraphQL Engine

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- CORE TABLES
-- ============================================================================

-- Users table (basic user information)
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Location types enum
CREATE TYPE location_type AS ENUM ('physical', 'online', 'fuzzy');

-- Locations table (physical, online, or fuzzy locations)
CREATE TABLE locations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    location_type location_type NOT NULL,
    -- For physical locations
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    address TEXT,
    -- For fuzzy locations (e.g., "any hardware store")
    category TEXT, -- e.g., "hardware_store", "grocery_store"
    search_radius_km INTEGER, -- search radius for fuzzy locations
    -- Metadata
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CHECK (
        (location_type = 'physical' AND latitude IS NOT NULL AND longitude IS NOT NULL) OR
        (location_type = 'online') OR
        (location_type = 'fuzzy' AND category IS NOT NULL)
    )
);

-- Time window types (seasonal periods defined by user)
CREATE TABLE time_windows (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL, -- e.g., "snowmobile_season", "chicken_outdoor_season"
    description TEXT,
    started_at TIMESTAMP WITH TIME ZONE, -- when user declared it started
    ended_at TIMESTAMP WITH TIME ZONE, -- when user declared it ended
    is_active BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Weather condition types
CREATE TYPE weather_condition_type AS ENUM (
    'snow_precipitation',
    'rain_precipitation',
    'temperature_above',
    'temperature_below',
    'any'
);

-- Weather conditions table
CREATE TABLE weather_conditions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    condition_type weather_condition_type NOT NULL,
    threshold_value DECIMAL(5, 2), -- temperature threshold or precipitation amount
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Time constraint types
CREATE TYPE time_constraint_type AS ENUM (
    'absolute', -- specific date/time
    'relative_time_of_day', -- morning, afternoon, evening, night
    'relative_solar', -- dawn, dusk (calculated from lat/long)
    'business_hours', -- during business hours
    'after_event', -- after a specific event/condition
    'recurring' -- recurring pattern
);

-- Time of day enum
CREATE TYPE time_of_day AS ENUM ('morning', 'afternoon', 'evening', 'night');

-- Tasks table (core task data)
CREATE TABLE tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    description TEXT,

    -- Location constraints
    location_id UUID REFERENCES locations(id) ON DELETE SET NULL,

    -- Time constraints
    time_constraint_type time_constraint_type,
    absolute_start_time TIMESTAMP WITH TIME ZONE,
    absolute_end_time TIMESTAMP WITH TIME ZONE,
    relative_time_of_day time_of_day,
    requires_business_hours BOOLEAN DEFAULT FALSE,

    -- Time window constraint (seasonal)
    time_window_id UUID REFERENCES time_windows(id) ON DELETE SET NULL,

    -- Weather constraint
    weather_condition_id UUID REFERENCES weather_conditions(id) ON DELETE SET NULL,
    requires_weather_condition BOOLEAN DEFAULT FALSE,

    -- Priority and urgency
    base_priority INTEGER DEFAULT 50 CHECK (base_priority >= 0 AND base_priority <= 100),
    calculated_priority INTEGER DEFAULT 50 CHECK (calculated_priority >= 0 AND calculated_priority <= 100),

    -- Deadline
    deadline TIMESTAMP WITH TIME ZONE,
    deadline_urgency_multiplier DECIMAL(3, 2) DEFAULT 1.0,

    -- Status
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'assigned', 'blocked', 'completed', 'cancelled')),

    -- Completion tracking
    completed_at TIMESTAMP WITH TIME ZONE,
    completed_by UUID REFERENCES users(id) ON DELETE SET NULL,

    -- Estimated duration (in minutes)
    estimated_duration_minutes INTEGER,

    -- LLM-generated metadata
    llm_generated_subtasks BOOLEAN DEFAULT FALSE,
    llm_category TEXT, -- category assigned by LLM for batching

    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES users(id) ON DELETE SET NULL
);

-- Task dependencies (many-to-many)
CREATE TABLE task_dependencies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    depends_on_task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(task_id, depends_on_task_id),
    CHECK (task_id != depends_on_task_id)
);

-- Recurring schedules
CREATE TYPE recurrence_type AS ENUM ('daily', 'weekly', 'monthly', 'custom');

CREATE TABLE recurring_schedules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    recurrence_type recurrence_type NOT NULL,

    -- For daily recurrence
    time_of_day time_of_day,

    -- For weekly recurrence
    day_of_week INTEGER CHECK (day_of_week >= 0 AND day_of_week <= 6), -- 0 = Sunday

    -- For monthly recurrence
    day_of_month INTEGER CHECK (day_of_month >= 1 AND day_of_month <= 31),

    -- Time window constraint (only active during certain periods)
    time_window_id UUID REFERENCES time_windows(id) ON DELETE SET NULL,

    -- Next occurrence
    next_occurrence TIMESTAMP WITH TIME ZONE,
    last_generated_at TIMESTAMP WITH TIME ZONE,

    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Task assignments (one task at a time per user)
CREATE TABLE task_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,

    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,

    -- Current location when assigned
    assigned_location_latitude DECIMAL(10, 8),
    assigned_location_longitude DECIMAL(11, 8),

    is_active BOOLEAN DEFAULT TRUE,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Blockers (conditions preventing task completion)
CREATE TABLE blockers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    description TEXT NOT NULL,

    -- If blocker was resolved by creating sub-tasks
    resolved BOOLEAN DEFAULT FALSE,
    resolved_at TIMESTAMP WITH TIME ZONE,
    resolution_notes TEXT,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES users(id) ON DELETE SET NULL
);

-- Task history (completion/progress tracking)
CREATE TABLE task_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    event_type TEXT NOT NULL CHECK (event_type IN ('started', 'completed', 'blocked', 'cancelled', 'gratification')),

    -- For blocked events
    blocker_id UUID REFERENCES blockers(id) ON DELETE SET NULL,

    -- Gratification tracking
    gratification_message TEXT,

    notes TEXT,
    occurred_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Task categories (LLM-generated for batching similar tasks)
CREATE TABLE task_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL UNIQUE,
    description TEXT,

    -- Category metadata for LLM
    category_keywords TEXT[], -- array of keywords for matching
    batch_compatible BOOLEAN DEFAULT TRUE, -- can tasks in this category be batched?

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Task category assignments (many-to-many)
CREATE TABLE task_category_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    category_id UUID NOT NULL REFERENCES task_categories(id) ON DELETE CASCADE,

    confidence_score DECIMAL(3, 2) CHECK (confidence_score >= 0 AND confidence_score <= 1),
    assigned_by_llm BOOLEAN DEFAULT FALSE,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(task_id, category_id)
);

-- ============================================================================
-- INDEXES
-- ============================================================================

-- Tasks indexes
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_location ON tasks(location_id);
CREATE INDEX idx_tasks_deadline ON tasks(deadline);
CREATE INDEX idx_tasks_priority ON tasks(calculated_priority DESC);
CREATE INDEX idx_tasks_created_by ON tasks(created_by);
CREATE INDEX idx_tasks_time_window ON tasks(time_window_id);
CREATE INDEX idx_tasks_category ON tasks(llm_category);

-- Task dependencies indexes
CREATE INDEX idx_task_dependencies_task ON task_dependencies(task_id);
CREATE INDEX idx_task_dependencies_depends_on ON task_dependencies(depends_on_task_id);

-- Task assignments indexes
CREATE INDEX idx_task_assignments_user ON task_assignments(user_id);
CREATE INDEX idx_task_assignments_task ON task_assignments(task_id);
CREATE INDEX idx_task_assignments_active ON task_assignments(user_id, is_active) WHERE is_active = TRUE;

-- Unique constraint: only one active assignment per user at a time
CREATE UNIQUE INDEX idx_task_assignments_one_active_per_user
    ON task_assignments(user_id) WHERE is_active = TRUE;

-- Task history indexes
CREATE INDEX idx_task_history_task ON task_history(task_id);
CREATE INDEX idx_task_history_user ON task_history(user_id);
CREATE INDEX idx_task_history_event_type ON task_history(event_type);
CREATE INDEX idx_task_history_occurred_at ON task_history(occurred_at DESC);

-- Locations indexes
CREATE INDEX idx_locations_type ON locations(location_type);
CREATE INDEX idx_locations_category ON locations(category);
CREATE INDEX idx_locations_coordinates ON locations(latitude, longitude);

-- Time windows indexes
CREATE INDEX idx_time_windows_active ON time_windows(is_active) WHERE is_active = TRUE;

-- Recurring schedules indexes
CREATE INDEX idx_recurring_schedules_task ON recurring_schedules(task_id);
CREATE INDEX idx_recurring_schedules_active ON recurring_schedules(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_recurring_schedules_next_occurrence ON recurring_schedules(next_occurrence);

-- ============================================================================
-- FUNCTIONS AND TRIGGERS
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply updated_at trigger to relevant tables
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_locations_updated_at BEFORE UPDATE ON locations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_time_windows_updated_at BEFORE UPDATE ON time_windows
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_weather_conditions_updated_at BEFORE UPDATE ON weather_conditions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_tasks_updated_at BEFORE UPDATE ON tasks
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_recurring_schedules_updated_at BEFORE UPDATE ON recurring_schedules
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_task_assignments_updated_at BEFORE UPDATE ON task_assignments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_task_categories_updated_at BEFORE UPDATE ON task_categories
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to calculate task priority based on deadline urgency
CREATE OR REPLACE FUNCTION calculate_task_priority()
RETURNS TRIGGER AS $$
DECLARE
    days_until_deadline DECIMAL;
    urgency_factor DECIMAL;
BEGIN
    IF NEW.deadline IS NOT NULL THEN
        days_until_deadline := EXTRACT(EPOCH FROM (NEW.deadline - NOW())) / 86400.0;

        IF days_until_deadline < 0 THEN
            -- Overdue - maximum priority
            NEW.calculated_priority := 100;
        ELSIF days_until_deadline < 1 THEN
            -- Less than 1 day - very high priority
            urgency_factor := 1.0 + (1.0 - days_until_deadline) * NEW.deadline_urgency_multiplier;
            NEW.calculated_priority := LEAST(100, NEW.base_priority * urgency_factor);
        ELSIF days_until_deadline < 7 THEN
            -- Less than 1 week - increasing urgency
            urgency_factor := 1.0 + ((7.0 - days_until_deadline) / 7.0) * 0.5 * NEW.deadline_urgency_multiplier;
            NEW.calculated_priority := LEAST(100, NEW.base_priority * urgency_factor);
        ELSE
            -- More than 1 week - base priority
            NEW.calculated_priority := NEW.base_priority;
        END IF;
    ELSE
        NEW.calculated_priority := NEW.base_priority;
    END IF;

    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply priority calculation trigger
CREATE TRIGGER calculate_tasks_priority BEFORE INSERT OR UPDATE ON tasks
    FOR EACH ROW EXECUTE FUNCTION calculate_task_priority();

-- ============================================================================
-- VIEWS
-- ============================================================================

-- View for active tasks eligible for assignment
CREATE VIEW eligible_tasks AS
SELECT
    t.*,
    l.name as location_name,
    l.location_type,
    l.latitude as location_latitude,
    l.longitude as location_longitude,
    tw.name as time_window_name,
    tw.is_active as time_window_active,
    wc.name as weather_condition_name,
    COUNT(DISTINCT td.depends_on_task_id) as dependency_count,
    COUNT(DISTINCT td2.task_id) FILTER (WHERE t2.status != 'completed') as unmet_dependencies
FROM tasks t
LEFT JOIN locations l ON t.location_id = l.id
LEFT JOIN time_windows tw ON t.time_window_id = tw.id
LEFT JOIN weather_conditions wc ON t.weather_condition_id = wc.id
LEFT JOIN task_dependencies td ON t.id = td.task_id
LEFT JOIN task_dependencies td2 ON t.id = td2.task_id
LEFT JOIN tasks t2 ON td2.depends_on_task_id = t2.id
WHERE t.status = 'pending'
    AND (t.time_window_id IS NULL OR tw.is_active = TRUE)
GROUP BY t.id, l.id, tw.id, wc.id
HAVING COUNT(DISTINCT td2.task_id) FILTER (WHERE t2.status != 'completed') = 0
ORDER BY t.calculated_priority DESC, t.created_at ASC;

-- View for user's current active assignment
CREATE VIEW active_assignments AS
SELECT
    ta.*,
    t.title as task_title,
    t.description as task_description,
    t.estimated_duration_minutes,
    u.name as user_name,
    u.email as user_email
FROM task_assignments ta
JOIN tasks t ON ta.task_id = t.id
JOIN users u ON ta.user_id = u.id
WHERE ta.is_active = TRUE;

-- View for task statistics per user
CREATE VIEW user_task_stats AS
SELECT
    u.id as user_id,
    u.name as user_name,
    COUNT(DISTINCT th.task_id) FILTER (WHERE th.event_type = 'completed') as completed_count,
    COUNT(DISTINCT th.task_id) FILTER (WHERE th.event_type = 'blocked') as blocked_count,
    COUNT(DISTINCT th.task_id) FILTER (WHERE th.event_type = 'gratification') as gratification_count,
    MAX(th.occurred_at) FILTER (WHERE th.event_type = 'completed') as last_completion_at
FROM users u
LEFT JOIN task_history th ON u.id = th.user_id
GROUP BY u.id, u.name;

-- ============================================================================
-- SAMPLE DATA (for testing)
-- ============================================================================

-- Insert sample user
INSERT INTO users (name, email) VALUES ('Test User', 'test@example.com');

-- Insert sample locations
INSERT INTO locations (name, location_type, latitude, longitude, address) VALUES
    ('Home', 'physical', 45.5017, -73.5673, '123 Main St, Montreal, QC'),
    ('Office', 'physical', 45.5088, -73.5540, '456 Work Ave, Montreal, QC');

INSERT INTO locations (name, location_type) VALUES
    ('Computer', 'online');

INSERT INTO locations (name, location_type, category, search_radius_km) VALUES
    ('Any Hardware Store', 'fuzzy', 'hardware_store', 10);

-- Insert sample time windows
INSERT INTO time_windows (name, description, is_active) VALUES
    ('Snowmobile Season', 'Winter snowmobile season', FALSE),
    ('Chicken Outdoor Season', 'When chickens are free-range', TRUE);

-- Insert sample weather conditions
INSERT INTO weather_conditions (name, condition_type) VALUES
    ('After Snow', 'snow_precipitation'),
    ('After Rain', 'rain_precipitation');

-- Insert sample tasks
INSERT INTO tasks (title, description, base_priority, created_by, location_id)
SELECT
    'Water the chickens',
    'Daily task to water the chickens in winter',
    60,
    u.id,
    l.id
FROM users u, locations l
WHERE u.email = 'test@example.com' AND l.name = 'Home';

INSERT INTO tasks (title, description, base_priority, deadline, created_by, location_id)
SELECT
    'Buy replacement part',
    'Get a replacement part from hardware store',
    50,
    NOW() + INTERVAL '7 days',
    u.id,
    l.id
FROM users u, locations l
WHERE u.email = 'test@example.com' AND l.name = 'Any Hardware Store';

INSERT INTO tasks (title, description, base_priority, created_by, location_id)
SELECT
    'Pay utility bill',
    'Pay the electricity bill online',
    70,
    u.id,
    l.id
FROM users u, locations l
WHERE u.email = 'test@example.com' AND l.name = 'Computer';