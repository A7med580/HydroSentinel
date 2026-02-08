-- POLICY 1: Allow authenticated users to view (list/download) files in 'factories'
CREATE POLICY "Allow authenticated view factories"
ON storage.objects FOR SELECT
TO authenticated
USING ( bucket_id = 'factories' );

-- POLICY 2: Allow authenticated users to upload to 'factories'
CREATE POLICY "Allow authenticated upload factories"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK ( bucket_id = 'factories' );

-- Verify the bucket exists (Optional, just to be safe)
INSERT INTO storage.buckets (id, name, public)
VALUES ('factories', 'factories', true)
ON CONFLICT (id) DO UPDATE SET public = true;
