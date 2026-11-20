UPDATE vehicles
SET vehicle_status = 'ACTIVE'
WHERE vehicle_status IN ('AVAILABLE', 'ASSIGNED');

ALTER TABLE vehicles
ADD CONSTRAINT chk_vehicle_status
CHECK (vehicle_status IN ('ACTIVE', 'MAINTENANCE', 'INACTIVE'));
