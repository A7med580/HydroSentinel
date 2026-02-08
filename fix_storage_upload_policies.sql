-- Storage policies for factories bucket to allow file uploads

-- 1. Allow authenticated users to INSERT/upload files to their own user folders
CREATE POLICY "Allow authenticated users to upload files"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'factories' 
  AND auth.uid() IS NOT NULL
);

-- 2. Allow authenticated users to READ files from their folders
CREATE POLICY "Allow authenticated users to read files"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'factories'
  AND auth.uid() IS NOT NULL
);

-- 3. Allow authenticated users to UPDATE files (for overwrites)
CREATE POLICY "Allow authenticated users to update files"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'factories'
  AND auth.uid() IS NOT NULL
);

-- 4. Allow authenticated users to DELETE files
CREATE POLICY "Allow authenticated users to delete files"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'factories'
  AND auth.uid() IS NOT NULL
);
