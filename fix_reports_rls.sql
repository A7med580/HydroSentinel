-- NUCLEAR FIX: Reset and Re-Apply Reports Permissions & Constraints
-- Run this in Supabase SQL Editor to unblock Sync/Pruning once and for all.

-- 1. DELETE DUPLICATES (If any exist, we must clear them to add the constraint)
-- This keeps only the newest record for each file path.
DELETE FROM reports r1
USING reports r2
WHERE r1.id < r2.id
  AND r1.file_id = r2.file_id;

-- 2. ADD UNIQUE CONSTRAINT (The permanent fix)
ALTER TABLE reports ADD CONSTRAINT unique_file_id UNIQUE (file_id);

-- 2. Ensure RLS is enabled
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

-- 3. Drop existing policies to prevent "Policy already exists" errors
DROP POLICY IF EXISTS "Users can update reports of own factories" ON reports;
DROP POLICY IF EXISTS "Users can delete reports of own factories" ON reports;
DROP POLICY IF EXISTS "Users can view reports of own factories" ON reports;
DROP POLICY IF EXISTS "Users can create reports for own factories" ON reports;

-- 3. Re-Create ALL Policies with Correct Logic

-- VIEW
CREATE POLICY "Users can view reports of own factories" ON reports
  FOR SELECT USING (
    exists (
      select 1 from factories
      where factories.id = reports.factory_id
      and factories.user_id = auth.uid()
    )
  );

-- INSERT
CREATE POLICY "Users can create reports for own factories" ON reports
  FOR INSERT WITH CHECK (
    exists (
      select 1 from factories
      where factories.id = reports.factory_id
      and factories.user_id = auth.uid()
    )
  );

-- UPDATE (Fixes 69% vs 91% discrepancy)
CREATE POLICY "Users can update reports of own factories" ON reports
  FOR UPDATE USING (
    exists (
      select 1 from factories
      where factories.id = reports.factory_id
      and factories.user_id = auth.uid()
    )
  );

-- DELETE (Fixes Duplicate Factory B issue)
CREATE POLICY "Users can delete reports of own factories" ON reports
  FOR DELETE USING (
    exists (
      select 1 from factories
      where factories.id = reports.factory_id
      and factories.user_id = auth.uid()
    )
  );
