-- HydroSentinel V2 Schema Migration
-- Defines the new data architecture for high-precision time-series data

-- 1. Measurements V2: The Single Source of Truth
CREATE TABLE measurements_v2 (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  factory_id UUID REFERENCES factories(id) ON DELETE CASCADE,
  
  -- Time Definition
  period_type TEXT CHECK (period_type IN ('daily', 'weekly', 'monthly', 'yearly')),
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  
  -- Data Source Tracking
  upload_id UUID, -- Link to uploads_log (FK added later)
  
  -- Data Payload (Stores strict chemical parameters)
  -- Example: {"ph": 7.2, "conductivity": 1200, "chlorides": 150}
  data JSONB NOT NULL DEFAULT '{}'::jsonb,
  
  -- Calculated Indices (LSI, RSI, PSI)
  -- Example: {"lsi": 1.2, "rsi": 6.5}
  indices JSONB NOT NULL DEFAULT '{}'::jsonb,
  
  -- Meta
  is_active BOOLEAN DEFAULT TRUE, -- Soft delete / Version control
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Indexes for Performance
-- critical for "Give me all data for Factory X in 2025"
CREATE INDEX idx_measurements_v2_factory_date ON measurements_v2(factory_id, start_date);
-- critical for "Give me only Daily data"
CREATE INDEX idx_measurements_v2_period ON measurements_v2(factory_id, period_type);

-- 3. Uploads Log: Tracking the "Chaos"
-- Stores every file ever uploaded, status, and what time range it covered
CREATE TABLE uploads_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id),
  factory_id UUID REFERENCES factories(id) ON DELETE CASCADE,
  
  filename TEXT NOT NULL,
  file_path TEXT NOT NULL, -- Storage path
  template_type TEXT, -- 'daily', 'weekly', etc.
  
  -- Date range covered by this file
  range_start DATE,
  range_end DATE,
  
  status TEXT CHECK (status IN ('processing', 'success', 'failed', 'partial')),
  error_message TEXT,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. RLS Policies (Security)
ALTER TABLE measurements_v2 ENABLE ROW LEVEL SECURITY;
ALTER TABLE uploads_log ENABLE ROW LEVEL SECURITY;

-- Measurements policies
CREATE POLICY "Users can view measurements for their factories"
ON measurements_v2 FOR SELECT
USING (
  auth.uid() IN (
    SELECT user_id FROM factories WHERE id = measurements_v2.factory_id
  )
);

CREATE POLICY "Users can insert measurements for their factories"
ON measurements_v2 FOR INSERT
WITH CHECK (
  auth.uid() IN (
    SELECT user_id FROM factories WHERE id = measurements_v2.factory_id
  )
);

CREATE POLICY "Users can update measurements for their factories"
ON measurements_v2 FOR UPDATE
USING (
  auth.uid() IN (
    SELECT user_id FROM factories WHERE id = measurements_v2.factory_id
  )
);

CREATE POLICY "Users can delete measurements for their factories"
ON measurements_v2 FOR DELETE
USING (
  auth.uid() IN (
    SELECT user_id FROM factories WHERE id = measurements_v2.factory_id
  )
);

-- Uploads Log policies
CREATE POLICY "Users can view their own upload logs"
ON uploads_log FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own upload logs"
ON uploads_log FOR INSERT
WITH CHECK (auth.uid() = user_id);
