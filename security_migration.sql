-- 1. ADD USER_ID COLUMN
-- We first allow nulls to not break existing rows, then we should backfill or truncate.
-- Since this is a hard security cutover, we will TRUNCATE factories to ensure clean state.
TRUNCATE TABLE reports, factories;

ALTER TABLE factories 
ADD COLUMN user_id uuid references auth.users not null;

-- 2. UPDATE RLS POLICIES FOR FACTORIES

-- Drop old policies to be safe
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON factories;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON factories;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON factories;

-- Create new strict policies
CREATE POLICY "Users can view own factories" ON factories
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create own factories" ON factories
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own factories" ON factories
  FOR UPDATE USING (auth.uid() = user_id);

-- 3. UPDATE RLS POLICIES FOR REPORTS
-- Reports access depends on Factory access

DROP POLICY IF EXISTS "Enable read access for reports" ON reports;
DROP POLICY IF EXISTS "Enable insert for reports" ON reports;

CREATE POLICY "Users can view reports of own factories" ON reports
  FOR SELECT USING (
    exists (
      select 1 from factories
      where factories.id = reports.factory_id
      and factories.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can create reports for own factories" ON reports
  FOR INSERT WITH CHECK (
    exists (
      select 1 from factories
      where factories.id = reports.factory_id
      and factories.user_id = auth.uid()
    )
  );
