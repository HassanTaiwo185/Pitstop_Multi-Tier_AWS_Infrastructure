
-- PostgreSQL schema for PitStop Motors inventory

CREATE SCHEMA IF NOT EXISTS pitstop;

CREATE TABLE IF NOT EXISTS pitstop.inventory (
    id              SERIAL PRIMARY KEY,
    sku             VARCHAR(32) UNIQUE NOT NULL,
    name            VARCHAR(120) NOT NULL,
    description     TEXT,
    category        VARCHAR(60) NOT NULL,
    quantity        INTEGER NOT NULL DEFAULT 0 CHECK (quantity >= 0),
    unit_cost_cad   NUMERIC(10,2) NOT NULL CHECK (unit_cost_cad >= 0),
    supplier        VARCHAR(120),
    purchaser       VARCHAR(120) NOT NULL,
    location        VARCHAR(120) DEFAULT 'Front Stockroom',
    received_at     DATE NOT NULL DEFAULT CURRENT_DATE,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


CREATE INDEX IF NOT EXISTS idx_inventory_category ON pitstop.inventory (category);
CREATE INDEX IF NOT EXISTS idx_inventory_purchaser ON pitstop.inventory (purchaser);
CREATE INDEX IF NOT EXISTS idx_inventory_received ON pitstop.inventory (received_at);

-- Dummy data
INSERT INTO pitstop.inventory (sku, name, description, category, quantity, unit_cost_cad, supplier, purchaser, location, received_at)
VALUES
('OIL-5W30-01', '5W-30 Synthetic Oil (4L)', 'Full synthetic engine oil, API SP', 'Fluids', 24, 34.99, 'LubeCo Canada', 'Alex Rivera', 'Bay A Shelf 1', CURRENT_DATE - INTERVAL '21 days'),
('FLT-ENG-123', 'Engine Oil Filter A123', 'Compatible with common 4-cyl models', 'Filters', 40, 9.50, 'Autoworks Supply', 'Jordan Lee', 'Bay A Shelf 2', CURRENT_DATE - INTERVAL '18 days'),
('BRK-PAD-FT1', 'Front Brake Pads Set', 'Ceramic pads, low dust', 'Brakes', 12, 54.00, 'BrakePro', 'Sam Chen', 'Bay B Shelf 3', CURRENT_DATE - INTERVAL '30 days'),
('BRK-ROT-280', 'Rotor 280mm', 'Vented rotor, 5x114.3', 'Brakes', 8, 68.75, 'BrakePro', 'Alex Rivera', 'Bay B Shelf 3', CURRENT_DATE - INTERVAL '29 days'),
('TIR-ALL-SEAS', 'All-Season Tire 205/55R16', 'Treadwear 600, H-speed', 'Tires', 16, 109.99, 'RoadMax', 'Morgan Patel', 'Tire Rack 2', CURRENT_DATE - INTERVAL '10 days'),
('BAT-12V-600', '12V Battery 600 CCA', 'Maintenance-free AGM', 'Electrical', 6, 149.00, 'VoltSource', 'Jordan Lee', 'Bay C Shelf 1', CURRENT_DATE - INTERVAL '14 days'),
('BELT-SERP-01', 'Serpentine Belt 6PK1115', 'EPDM belt', 'Belts', 14, 22.40, 'DriveLine', 'Hassan Ayinde', 'Bay D Drawer 2', CURRENT_DATE - INTERVAL '7 days'),
('WPR-BLD-600', 'Wiper Blade 24"', 'All-season blade', 'Accessories', 20, 12.99, 'ClearView', 'Sam Chen', 'Front Counter', CURRENT_DATE - INTERVAL '12 days'),
('COOL-50-50', 'Premix Coolant 50/50 (4L)', 'Silicate-free formula', 'Fluids', 10, 18.75, 'LubeCo Canada', 'Morgan Patel', 'Bay A Shelf 4', CURRENT_DATE - INTERVAL '15 days'),
('SENS-O2-001', 'O2 Sensor Universal', '4-wire heated sensor', 'Sensors', 5, 45.35, 'AutoSensors Inc.', 'Hassan Ayinde', 'Bay E Bin 3', CURRENT_DATE - INTERVAL '27 days')
ON CONFLICT (sku) DO NOTHING;