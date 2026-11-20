CREATE TABLE app_users (
    id UUID PRIMARY KEY,
    full_name VARCHAR(80) NOT NULL,
    email VARCHAR(254) NOT NULL UNIQUE,
    password_hash VARCHAR(100) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE vehicles (
    id UUID PRIMARY KEY,
    owner_id UUID NOT NULL REFERENCES app_users(id),
    vehicle_name VARCHAR(50) NOT NULL,
    manufacturer VARCHAR(50) NOT NULL,
    model VARCHAR(50) NOT NULL,
    color VARCHAR(30) NOT NULL,
    seat_capacity INTEGER NOT NULL CHECK (seat_capacity BETWEEN 1 AND 80),
    number_plate VARCHAR(50) NOT NULL,
    engine_cc INTEGER NOT NULL CHECK (engine_cc BETWEEN 0 AND 20000),
    vehicle_type VARCHAR(30) NOT NULL,
    fuel_type VARCHAR(30) NOT NULL,
    vehicle_status VARCHAR(30) NOT NULL,
    assigned_depot VARCHAR(100) NOT NULL,
    manufacture_year INTEGER NOT NULL CHECK (manufacture_year BETWEEN 1950 AND 2100),
    notes VARCHAR(500),
    is_deleted BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Guarantees active plates are globally unique, even during concurrent API requests.
-- Historical, soft-deleted rows remain stored.
CREATE UNIQUE INDEX ux_vehicles_active_plate ON vehicles (number_plate)
WHERE is_deleted = false;
CREATE INDEX ix_vehicles_owner_active ON vehicles (owner_id, created_at DESC)
WHERE is_deleted = false;
