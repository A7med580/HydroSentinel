-- Migration: Add Measurements Table for Time-Based Analytics
-- Version: 1.0
-- Date: 2024-02-07

-- ============================================
-- 1. CREATE MEASUREMENTS TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS measurements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  factory_id uuid REFERENCES factories(id) ON DELETE CASCADE NOT NULL,
  measurement_date date NOT NULL,
  
  -- Raw Cooling Tower Parameters (for aggregation)
  ph numeric(4,2) CHECK (ph >= 0 AND ph <= 14),
  alkalinity numeric(6,2) CHECK (alkalinity >= 0),
  conductivity numeric(8,2) CHECK (conductivity >= 0),
  total_hardness numeric(6,2) CHECK (total_hardness >= 0),
  chloride numeric(6,2) CHECK (chloride >= 0),
  zinc numeric(5,3) CHECK (zinc >= 0),
  iron numeric(5,3) CHECK (iron >= 0),
  phosphates numeric(6,2) CHECK (phosphates >= 0),
  
  -- RO Parameters (optional, nullable)
  ro_free_chlorine numeric(5,3) CHECK (ro_free_chlorine >= 0 OR ro_free_chlorine IS NULL),
  ro_silica numeric(6,2) CHECK (ro_silica >= 0 OR ro_silica IS NULL),
  ro_conductivity numeric(6,2) CHECK (ro_conductivity >= 0 OR ro_conductivity IS NULL),
  
  -- Pre-calculated Indices (for quick display)
  lsi numeric(6,3),
  rsi numeric(6,3),
  psi numeric(6,3),
  
  -- Pre-calculated Risks (0-100 scale)
  risk_scaling numeric(5,2) CHECK (risk_scaling >= 0 AND risk_scaling <= 100),
  risk_corrosion numeric(5,2) CHECK (risk_corrosion >= 0 AND risk_corrosion <= 100),
  risk_fouling numeric(5,2) CHECK (risk_fouling >= 0 AND risk_fouling <= 100),
  
  -- Metadata
  source_file_id text NOT NULL,
  source_file_name text,
  uploaded_at timestamptz DEFAULT now() NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  
  -- Ensure one measurement per date per file (allow multiple files for same date)
  CONSTRAINT unique_measurement_per_file UNIQUE(factory_id, measurement_date, source_file_id)
);

-- ============================================
-- 2. CREATE INDEXES FOR PERFORMANCE
-- ============================================

-- Primary query: Get all measurements for a factory within a date range
CREATE INDEX idx_measurements_factory_date 
ON measurements(factory_id, measurement_date DESC);

-- Query by file (for sync/deduplication)
CREATE INDEX idx_measurements_file 
ON measurements(source_file_id);

-- Recent measurements (dashboard landing)
CREATE INDEX idx_measurements_recent 
ON measurements(factory_id, uploaded_at DESC);

-- ============================================
-- 3. ENABLE ROW LEVEL SECURITY
-- ============================================

ALTER TABLE measurements ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any (idempotent)
DROP POLICY IF EXISTS "Users can view measurements of own factories" ON measurements;
DROP POLICY IF EXISTS "Users can create measurements for own factories" ON measurements;
DROP POLICY IF EXISTS "Users can update measurements of own factories" ON measurements;
DROP POLICY IF EXISTS "Users can delete measurements of own factories" ON measurements;

-- SELECT: Users can view measurements of their factories
CREATE POLICY "Users can view measurements of own factories" ON measurements
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM factories
      WHERE factories.id = measurements.factory_id
      AND factories.user_id = auth.uid()
    )
  );

-- INSERT: Users can create measurements for their factories
CREATE POLICY "Users can create measurements for own factories" ON measurements
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM factories
      WHERE factories.id = measurements.factory_id
      AND factories.user_id = auth.uid()
    )
  );

-- UPDATE: Users can update measurements of their factories
CREATE POLICY "Users can update measurements of own factories" ON measurements
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM factories
      WHERE factories.id = measurements.factory_id
      AND factories.user_id = auth.uid()
    )
  );

-- DELETE: Users can delete measurements of their factories
CREATE POLICY "Users can delete measurements of own factories" ON measurements
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM factories
      WHERE factories.id = measurements.factory_id
      AND factories.user_id = auth.uid()
    )
  );

-- ============================================
-- 4. ADD HELPFUL COMMENTS
-- ============================================

COMMENT ON TABLE measurements IS 'Time-series water chemistry measurements for factory analytics';
COMMENT ON COLUMN measurements.measurement_date IS 'Actual date of water sampling (from Excel), not upload date';
COMMENT ON COLUMN measurements.source_file_id IS 'Storage path of the Excel file (matches reports.file_id)';
COMMENT ON CONSTRAINT unique_measurement_per_file ON measurements IS 'Prevents duplicate measurements from same file on same date';

-- ============================================
-- 5. VERIFICATION QUERIES (Optional)
-- ============================================

-- Verify table created
SELECT COUNT(*) as row_count FROM measurements;

-- Verify indexes
SELECT indexname, indexdef 
FROM pg_indexes 
WHERE tablename = 'measurements';

-- Verify RLS policies
SELECT policyname, cmd, qual 
FROM pg_policies 
WHERE tablename = 'measurements';
